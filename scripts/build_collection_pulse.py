#!/usr/bin/env python3
"""Build the public, evidence-labelled collection pulse for LetsHub.

This deliberately does *not* convert configured service targets or a workflow
completion into collected-record counts.  A collector may report a real count
through ``data/automation_runs.json``; until then the dashboard says that the
volume is not connected rather than presenting a synthetic trend.
"""
from __future__ import annotations

import json
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
KST = timezone(timedelta(hours=9))


def load(name: str, fallback):
    try:
        return json.loads((DATA / name).read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def timestamp(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def day_of(run: dict) -> str | None:
    moment = timestamp(run.get("completed_at") or run.get("observed_at") or run.get("started_at"))
    return moment.astimezone(KST).date().isoformat() if moment else None


def main() -> int:
    now = datetime.now(KST)
    live = load("live_operations.json", {})
    events = load("automation_runs.json", {"runs": []}).get("runs", [])
    observed = load("observability/latest.json", {})
    inventory = load("master_ecosystem_pulse.json", {})
    services = live.get("services", [])

    # Only explicit ingest counts are valid volume evidence.
    ingest_events = [
        event for event in events
        if event.get("status") == "SUCCESS"
        and str(event.get("stage", "")).upper() == "INGEST"
        and isinstance(event.get("observed", {}).get("count"), (int, float))
    ]
    dates = [(now.date() - timedelta(days=offset)).isoformat() for offset in range(13, -1, -1)]
    volume_by_day = defaultdict(float)
    runs_by_day = Counter()
    for event in events:
        date = day_of(event)
        if date in dates:
            runs_by_day[date] += 1
    for event in ingest_events:
        date = day_of(event)
        if date in dates:
            volume_by_day[date] += float(event["observed"]["count"])
    history = [
        {
            "date": date,
            "ingested_records": int(volume_by_day[date]) if date in volume_by_day else None,
            "run_events": runs_by_day[date],
            "volume_evidence": "observed" if date in volume_by_day else "not_connected",
        }
        for date in dates
    ]

    today, yesterday = dates[-1], dates[-2]
    today_volume, yesterday_volume = volume_by_day.get(today), volume_by_day.get(yesterday)
    delta_pct = None
    if today_volume is not None and yesterday_volume not in (None, 0):
        delta_pct = round((today_volume - yesterday_volume) / yesterday_volume * 100, 1)

    seven = dates[-7:]
    prior = dates[-14:-7]
    weekly_volume = sum(volume_by_day[d] for d in seven) if any(d in volume_by_day for d in seven) else None
    prior_volume = sum(volume_by_day[d] for d in prior) if any(d in volume_by_day for d in prior) else None
    weekly_delta = None
    if weekly_volume is not None and prior_volume not in (None, 0):
        weekly_delta = round((weekly_volume - prior_volume) / prior_volume * 100, 1)

    healthy = [item for item in services if item.get("status") == "healthy"]
    degraded = [item for item in services if item.get("status") == "degraded"]
    anomalies = []
    for item in degraded:
        label = item.get("label", "확인 필요")
        kind = "FAILED" if "실패" in label else "STALE" if "신선도" in label else "NEEDS_REVIEW"
        anomalies.append({
            "type": kind,
            "severity": "critical" if kind == "FAILED" else "warning",
            "service_id": item.get("id"),
            "service_name": item.get("name"),
            "message": item.get("detail") or label,
            "next_action": item.get("next"),
            "href": item.get("url"),
        })
    if today_volume is None or yesterday_volume is None:
        anomalies.append({
            "type": "VOLUME_NOT_CONNECTED",
            "severity": "info",
            "service_id": "all",
            "service_name": "수집량 원장",
            "message": "실제 적재 건수 이벤트가 연결되지 않아 전일·주간 수집량을 산정할 수 없습니다.",
            "next_action": "각 수집기 종료 시 automation_runs.json에 observed.count를 기록하세요.",
        })
    elif today_volume == 0 < yesterday_volume:
        anomalies.append({
            "type": "ZERO_DROP", "severity": "critical", "service_id": "all",
            "service_name": "수집량 원장", "message": "오늘 수집량이 0건입니다.",
            "next_action": "수집기 로그와 소스 접근 권한을 확인하세요.",
        })
    elif delta_pct is not None and delta_pct <= -30:
        anomalies.append({
            "type": "SHARP_DROP", "severity": "warning", "service_id": "all",
            "service_name": "수집량 원장", "message": f"전일 대비 {delta_pct}% 감소했습니다.",
            "next_action": "실행 로그와 외부 API 제한을 확인하세요.",
        })

    collect = observed.get("stages", {}).get("collect", {})
    analyze = observed.get("stages", {}).get("analyze", {})
    def rate(stage: dict) -> float | None:
        ok, fail = stage.get("ok"), stage.get("fail")
        if isinstance(ok, (int, float)) and isinstance(fail, (int, float)) and ok + fail:
            return round(ok / (ok + fail) * 100, 1)
        return None
    quality = {
        "source": "data/observability/latest.json" if observed else None,
        "collect_success_pct": rate(collect),
        "analyze_success_pct": rate(analyze),
        "quality_issue_count": observed.get("counts", {}).get("quality_issues"),
        "observed_at": observed.get("observed_at_kst") or observed.get("observed_at"),
    }
    payload = {
        "schema_version": "1.0.0",
        "generated_at": now.isoformat(),
        "provenance": {
            "workflow_state": "data/live_operations.json",
            "run_events": "data/automation_runs.json",
            "quality": "data/observability/latest.json",
            "rule": "Configured targets are never presented as observed collection volume.",
        },
        "summary": {
            "services_observed": len(services),
            "services_healthy": len(healthy),
            "services_needing_attention": len(degraded),
            "registered_nodes": len(inventory.get("automation_devices", [])),
            "today_ingested_records": int(today_volume) if today_volume is not None else None,
            "yesterday_ingested_records": int(yesterday_volume) if yesterday_volume is not None else None,
            "today_vs_yesterday_pct": delta_pct,
            "weekly_ingested_records": int(weekly_volume) if weekly_volume is not None else None,
            "weekly_vs_prior_pct": weekly_delta,
            "volume_evidence": "observed" if today_volume is not None else "not_connected",
        },
        "history": history,
        "quality": quality,
        "services": [{
            "id": item.get("id"), "name": item.get("name"), "state": item.get("status"),
            "label": item.get("label"), "last_updated": item.get("updated_at"),
            "age_hours": item.get("age_hours"), "detail": item.get("detail"),
            "next_action": item.get("next"), "href": item.get("url"),
        } for item in services],
        "anomalies": anomalies,
    }
    (DATA / "collection_pulse.json").write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"collection pulse: {len(services)} services, {len(anomalies)} alerts, volume={payload['summary']['volume_evidence']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
