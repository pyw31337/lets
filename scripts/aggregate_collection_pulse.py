#!/usr/bin/env python3
"""Create a public-safe collection pulse from observed collector events.

Configured targets and a completed workflow are not record counts. Only a
successful INGEST event with observed.count contributes to volume metrics.
Missing evidence stays null so the dashboard shows an unverified state.
"""
from __future__ import annotations

import json
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

KST = timezone(timedelta(hours=9))
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def event_day(event: dict) -> str | None:
    moment = parse_time(event.get("completed_at") or event.get("observed_at") or event.get("started_at"))
    return moment.astimezone(KST).date().isoformat() if moment else None


def success_rate(stage: dict):
    ok, fail = stage.get("ok"), stage.get("fail")
    if isinstance(ok, (int, float)) and isinstance(fail, (int, float)) and ok + fail:
        return round(ok / (ok + fail) * 100, 1)
    return None


def main() -> int:
    now = datetime.now(KST)
    live = load_json(DATA / "live_operations.json", {"services": []})
    events = load_json(DATA / "automation_runs.json", {"runs": []}).get("runs", [])
    observability = load_json(DATA / "observability" / "latest.json", {})
    inventory = load_json(DATA / "master_ecosystem_pulse.json", {})

    ingests = [
        event for event in events
        if event.get("status") == "SUCCESS"
        and str(event.get("stage", "")).upper() == "INGEST"
        and isinstance(event.get("observed", {}).get("count"), (int, float))
    ]
    dates = [(now.date() - timedelta(days=offset)).isoformat() for offset in range(13, -1, -1)]
    volume_by_day: dict[str, float] = defaultdict(float)
    service_volume_by_day: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    for event in ingests:
        day = event_day(event)
        if day in dates:
            volume_by_day[day] += float(event["observed"]["count"])
            if event.get("service_id"):
                service_volume_by_day[str(event["service_id"])][day] += float(event["observed"]["count"])

    history = [
        {"date": day, "collected": int(volume_by_day[day]) if day in volume_by_day else None,
         "evidence": "observed" if day in volume_by_day else "not_connected"}
        for day in dates
    ]
    today, yesterday = dates[-1], dates[-2]
    today_count, yesterday_count = volume_by_day.get(today), volume_by_day.get(yesterday)
    delta_pct = None
    if today_count is not None and yesterday_count not in (None, 0):
        delta_pct = round((today_count - yesterday_count) / yesterday_count * 100, 1)
    weekly = sum(volume_by_day[day] for day in dates[-7:]) if any(day in volume_by_day for day in dates[-7:]) else None
    prior_week = sum(volume_by_day[day] for day in dates[:7]) if any(day in volume_by_day for day in dates[:7]) else None
    weekly_delta = None
    if weekly is not None and prior_week not in (None, 0):
        weekly_delta = round((weekly - prior_week) / prior_week * 100, 1)

    services = live.get("services", [])
    degraded = [service for service in services if service.get("status") == "degraded"]
    alerts = [{
        "type": "FAILED" if "실패" in str(service.get("label")) else "STALE" if "신선도" in str(service.get("label")) else "NEEDS_REVIEW",
        "service_id": service.get("id"), "service": service.get("name"),
        "detail": service.get("detail"), "action": service.get("next"), "href": service.get("url"),
    } for service in degraded]
    if today_count is None or yesterday_count is None:
        alerts.append({"type": "VOLUME_NOT_CONNECTED", "service_id": "all", "service": "수집량 원장",
                       "detail": "실제 적재량 이벤트가 연결되지 않아 전일·주간 비교를 계산할 수 없습니다.",
                       "action": "수집기 완료 시 automation_runs.json에 INGEST observed.count를 기록하세요."})
    elif today_count == 0 < yesterday_count:
        alerts.append({"type": "ZERO_DROP", "service_id": "all", "service": "수집량 원장",
                       "detail": "오늘 실제 적재량이 0건입니다.", "action": "수집기와 원천 소스를 확인하세요."})
    elif delta_pct is not None and delta_pct <= -30:
        alerts.append({"type": "SHARP_DROP", "service_id": "all", "service": "수집량 원장",
                       "detail": f"전일 대비 {delta_pct}% 감소했습니다.", "action": "실행 로그와 API 제한을 확인하세요."})

    result = {
        "schema": "collection_pulse_v2", "generated_at": now.isoformat(),
        "provenance": {
            "workflow_state": "data/live_operations.json", "run_events": "data/automation_runs.json",
            "quality": "data/observability/latest.json",
            "rule": "Configured targets and workflow completion are never treated as observed record volume.",
        },
        "overall": {
            "volume_evidence": "observed" if today_count is not None else "not_connected",
            "today_collected": int(today_count) if today_count is not None else None,
            "yesterday_collected": int(yesterday_count) if yesterday_count is not None else None,
            "delta_pct": delta_pct, "week_current": int(weekly) if weekly is not None else None,
            "week_previous": int(prior_week) if prior_week is not None else None, "week_delta_pct": weekly_delta,
            "collectors_healthy": sum(service.get("status") == "healthy" for service in services),
            "collectors_total": len(services), "registered_nodes": len(inventory.get("automation_devices", [])),
        },
        "daily_trend": history,
        "service_volumes": {
            service_id: {
                "today": int(days[today]) if today in days else None,
                "yesterday": int(days[yesterday]) if yesterday in days else None,
            }
            for service_id, days in service_volume_by_day.items()
        },
        "quality": {
            "collect_success_pct": success_rate(observability.get("stages", {}).get("collect", {})),
            "analyze_success_pct": success_rate(observability.get("stages", {}).get("analyze", {})),
            "quality_issue_count": observability.get("counts", {}).get("quality_issues"),
            "observed_at": observability.get("observed_at_kst") or observability.get("observed_at"),
        },
        "services": services, "anomalies": alerts,
    }
    (DATA / "collection_pulse.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"collection pulse: {len(services)} services, volume={result['overall']['volume_evidence']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
