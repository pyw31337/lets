#!/usr/bin/env python3
"""Collect a small, public-safe GitHub operations snapshot for LetsHub.

The Pages site never receives a token. This job is the server-side collector;
it writes only links, counts and run metadata to data/live_operations.json.
"""
from __future__ import annotations

import json
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

OWNER = "pyw31337"
REPOS = [
    ("news", "뉴스보드"), ("culture", "컬처플로우"),
    ("pick", "렛츠픽"), ("hair", "렛츠헤어"), ("meat", "렛츠미트"),
    ("buy", "렛츠바이"), ("camp", "렛츠캠핑"), ("cctv", "렛츠CCTV"),
    ("metro", "렛츠메트로"), ("calendar", "렛츠캘린더"), ("law", "렛츠로"),
    ("insu", "렛츠인슈"), ("people", "렛츠피플"), ("asset", "렛츠에셋"),
    ("art", "렛츠아트"),
]
# A recent deployment is not enough to call a collector healthy. These
# windows make stale schedules visible instead of silently reporting green.
MAX_AGE_HOURS = {
    "news": 2, "culture": 36, "cctv": 12, "calendar": 36,
    "camp": 36, "meat": 36, "metro": 36, "pick": 36, "buy": 36,
    "hair": 36, "law": 36, "insu": 36, "people": 36, "asset": 36, "art": 36,
}
# Some repositories have deployment/recovery workflows that can run after a
# collector. Prefer the primary data workflow so a recovery run cannot mask a
# stale or failed ingestion run.
PRIMARY_WORKFLOWS = {
    "news": {"collect-news", "collect.yml"},
}
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data/live_operations.json"
RUN_EVENTS = ROOT / "data/automation_runs.json"
NEWS_OBSERVABILITY_URL = "https://raw.githubusercontent.com/pyw31337/news/data/observability/latest.json"
OBSERVABILITY_SOURCES = {
    "art": "https://raw.githubusercontent.com/pyw31337/art/main/data/observability/latest.json",
    "asset": "https://raw.githubusercontent.com/pyw31337/asset/main/data/observability/latest.json",
    "law": "https://raw.githubusercontent.com/pyw31337/law/main/data/observability/latest.json",
    "news": NEWS_OBSERVABILITY_URL,
    "people": "https://raw.githubusercontent.com/pyw31337/people/main/data/observability/latest.json",
}


def get_json(path: str, token: str | None):
    url = "https://api.github.com" + path
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "letshub-live-ops"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    for attempt in range(3):
        try:
            with urlopen(Request(url, headers=headers), timeout=15) as response:
                return json.loads(response.read().decode("utf-8")), None
        except HTTPError as exc:
            # Cross-repository GITHUB_TOKEN access is commonly rejected. Public
            # repositories can still be observed without a token.
            if exc.code in (401, 403) and token:
                try:
                    with urlopen(Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "letshub-live-ops"}), timeout=15) as response:
                        return json.loads(response.read().decode("utf-8")), None
                except Exception:
                    pass
            if exc.code in (429, 500, 502, 503, 504) and attempt < 2:
                time.sleep(1 + attempt)
                continue
            return None, f"HTTP {exc.code}"
        except (URLError, TimeoutError, json.JSONDecodeError) as exc:
            if attempt < 2:
                time.sleep(1 + attempt)
                continue
            return None, str(exc)
    return None, "request failed"


def iso(value: str | None) -> str | None:
    return value


def get_public_json(url: str):
    try:
        stamp = int(time.time() // 60)
        with urlopen(Request(f"{url}?t={stamp}", headers={"Accept": "application/json", "User-Agent": "letshub-live-ops"}), timeout=15) as response:
            return json.loads(response.read().decode("utf-8")), None
    except Exception as exc:
        return None, str(exc)


def record_workflow_events(services: list[dict]) -> None:
    """Keep a deduplicated execution ledger without inventing record volume.

    GitHub Actions tells us that a workflow ran, not how many business records
    it collected.  This ledger is intentionally limited to execution evidence;
    individual collectors may append ``observed.count`` when they know it.
    """
    try:
        ledger = json.loads(RUN_EVENTS.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        ledger = {"schema_version": "1.1.0", "runs": []}
    runs = ledger.setdefault("runs", [])
    seen = {str(run.get("source_run_id")) for run in runs if run.get("source_run_id")}
    for service in services:
        latest = service.get("latest_run") or {}
        url = latest.get("url")
        # The URL is stable per Actions run and works as an opaque run key.
        if not url or url in seen:
            continue
        conclusion, status = latest.get("conclusion"), latest.get("status")
        event_status = "SUCCESS" if conclusion == "success" else "FAILED" if conclusion in {"failure", "timed_out"} else "PENDING"
        runs.append({
            "source_run_id": url,
            "service_id": service.get("id"),
            "source": "github_actions",
            "workflow": latest.get("name"),
            "stage": "UNCLASSIFIED",
            "status": event_status,
            "completed_at": service.get("updated_at"),
            "observed": {"count": None, "unit": None},
            "note": "Workflow execution evidence only; collection volume was not reported by the workflow.",
        })
    # Prevent an indefinitely growing public asset.  90 days of 5-minute scans
    # is excessive because only new workflow runs are recorded; 5,000 is ample.
    ledger["schema_version"] = "1.1.0"
    ledger["generated_at"] = datetime.now(timezone.utc).isoformat()
    ledger["runs"] = runs[-5000:]
    ledger["note"] = "Workflow execution evidence. observed.count is populated only by collectors that report a real persisted-record count."
    RUN_EVENTS.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def record_observed_news_ingest(observability: dict | None) -> None:
    """Append a NewsBoard run only when its public observability ledger proves a count.

    The collector never derives a record count from an Actions result.  NewsBoard
    exposes both a stable run id and its persisted vote-row count, so it can be
    represented as a genuine INGEST event in the shared ledger.
    """
    if not isinstance(observability, dict):
        return
    run_id = observability.get("run_id")
    observed_at = observability.get("observed_at") or observability.get("observed_at_kst")
    count = (observability.get("counts") or {}).get("vote_rows")
    collect = (observability.get("stages") or {}).get("collect") or {}
    if not run_id or not observed_at or not isinstance(count, (int, float)) or collect.get("status") != "success":
        return
    try:
        ledger = json.loads(RUN_EVENTS.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        ledger = {"schema_version": "1.1.0", "runs": []}
    runs = ledger.setdefault("runs", [])
    source_run_id = f"news-observability:{run_id}"
    if any(run.get("source_run_id") == source_run_id for run in runs):
        return
    runs.append({
        "source_run_id": source_run_id,
        "service_id": "news",
        "source": "newsboard_observability",
        "workflow": observability.get("workflow"),
        "stage": "INGEST",
        "status": "SUCCESS",
        "completed_at": observed_at,
        "observed": {"count": int(count), "unit": "vote_rows"},
        "note": "NewsBoard public observability ledger: persisted vote-row count.",
    })
    ledger["schema_version"] = "1.1.0"
    ledger["generated_at"] = datetime.now(timezone.utc).isoformat()
    ledger["runs"] = runs[-5000:]
    ledger["note"] = "Workflow execution evidence. observed.count is populated only by collectors that report a real persisted-record count."
    RUN_EVENTS.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    token = os.getenv("LETS_STATUS_TOKEN") or os.getenv("GITHUB_TOKEN")
    now = datetime.now(timezone.utc)
    services, incidents, checks, warnings = [], [], [], []
    for repo, name in REPOS:
        base = f"/repos/{OWNER}/{repo}"
        meta, error = get_json(base, token)
        runs, runs_error = get_json(base + "/actions/runs?per_page=20", token)
        issues, issues_error = get_json(base + "/issues?state=open&per_page=10&sort=updated", token)
        if error and not meta:
            warnings.append(f"{repo}: {error}")
        if runs_error:
            warnings.append(f"{repo} runs: {runs_error}")
        run_items = (runs or {}).get("workflow_runs", []) if isinstance(runs, dict) else []
        primary = PRIMARY_WORKFLOWS.get(repo)
        relevant_runs = [
            r for r in run_items
            if not primary or r.get("name") in primary or str(r.get("path", "")).endswith("/collect.yml")
        ]
        latest = (relevant_runs or run_items)[0] if run_items else {}
        failed_steps = []
        jobs_error = None
        if latest.get("id"):
            jobs, jobs_error = get_json(f"{base}/actions/runs/{latest['id']}/jobs?per_page=100", token)
            if isinstance(jobs, dict):
                for job in jobs.get("jobs", []):
                    for step in job.get("steps", []) or []:
                        if step.get("conclusion") == "failure":
                            failed_steps.append(f"{job.get('name', 'job')}: {step.get('name', 'step')}")
            if jobs_error:
                warnings.append(f"{repo} jobs: {jobs_error}")
        latest_time = latest.get("updated_at") or latest.get("created_at")
        conclusion = latest.get("conclusion")
        age_hours = None
        if latest_time:
            try:
                age_hours = round((now - datetime.fromisoformat(latest_time.replace("Z", "+00:00"))).total_seconds() / 3600, 2)
            except ValueError:
                age_hours = None
        recent_failures = [r for r in (relevant_runs or run_items) if r.get("conclusion") in ("failure", "cancelled", "timed_out") and r.get("updated_at") and (now - datetime.fromisoformat(r["updated_at"].replace("Z", "+00:00"))).total_seconds() < 86400]
        open_items = [i for i in (issues or []) if "pull_request" not in i]
        status = "healthy"
        label, detail, next_action = "정상", "최근 GitHub Actions 실행 정상", "예약 실행 유지"
        if not latest:
            status, label, detail, next_action = "degraded", "확인 필요", "최근 실행 없음", "workflow 실행 또는 권한 확인"
            if error or runs_error:
                label, detail = "접근 확인", "GitHub Actions API 접근 권한 또는 저장소 공개 범위를 확인해야 합니다"
        elif conclusion in ("failure", "cancelled", "timed_out"):
            status, label = "degraded", "실패 감지"
            detail = f"최근 workflow {conclusion} · {latest.get('name', 'workflow')}"
            next_action = "실패 로그 확인 후 재실행"
        elif latest.get("status") in ("queued", "in_progress"):
            status, label = "degraded", "진행 중"
            detail = f"{latest.get('name', 'workflow')} 실행 중"
            next_action = "완료 결과 확인"
        elif conclusion != "success":
            status, label = "degraded", "결과 미확인"
            detail = f"최근 workflow 결과가 {conclusion or 'unknown'}입니다"
            next_action = "실행 결과와 로그 확인"
        elif failed_steps:
            status, label = "degraded", "단계 실패"
            detail = f"workflow는 완료됐지만 실패 단계 {len(failed_steps)}개 감지"
            next_action = "실패 단계 로그 확인"
        elif age_hours is not None and age_hours > MAX_AGE_HOURS.get(repo, 36):
            status, label = "degraded", "신선도 경과"
            detail = f"최근 성공 실행이 {age_hours:.1f}시간 전입니다"
            next_action = "예약 실행과 수집 신선도 확인"
        # 단순 공지나 핀 고정 정보성 이슈는 실제 긴급 처리 장애(incident)가 아니므로 제외
        actual_issues = [
            i for i in open_items
            if not any(k in i.get("title", "") for k in ["공지", "📌", "📢", "에이전트 공유", "용량 알림", "표준 프로세스"])
        ]
        if actual_issues:
            for issue in actual_issues[:2]:
                incidents.append({
                    "severity": "medium",
                    "title": f"{repo} 이슈 #{issue['number']}: {issue['title']}",
                    "service": name,
                    "why": "GitHub 운영 조치 필요",
                    "action": "이슈 확인 및 대응",
                    "href": issue["html_url"],
                    "updated_at": issue.get("updated_at")
                })
        for run in recent_failures[:2]:
            if run.get("conclusion") == "cancelled":
                continue # 수동 취소는 장애 인시던트로 잡지 않음
            incidents.append({
                "severity": "high",
                "title": f"{repo} 실행 실패: {run.get('name', 'workflow')}",
                "service": name,
                "why": f"{run.get('conclusion')} · {run.get('head_branch', 'main')}",
                "action": "실패 로그 확인 후 재실행",
                "href": run.get("html_url", f"https://github.com/{OWNER}/{repo}/actions"),
                "updated_at": run.get("updated_at")
            })
        services.append({
            "id": repo, "name": name, "status": status, "label": label,
            "detail": detail, "updated_at": iso(latest_time), "age_hours": age_hours,
            "url": f"https://github.com/{OWNER}/{repo}/actions",
            "repo": f"https://github.com/{OWNER}/{repo}", "next": next_action,
            "latest_run": {"name": latest.get("name"), "conclusion": conclusion, "status": latest.get("status"), "url": latest.get("html_url"), "failed_steps": failed_steps[:10]},
            "open_issues": len(open_items),
        })
    # NewsBoard의 실제 산출물 원장을 workflow 실행 상태와 별도로 확인한다.
    # GitHub Actions 성공만으로 분석·품질·게시가 끝났다고 판단하지 않는다.
    news_obs, news_obs_error = get_public_json(NEWS_OBSERVABILITY_URL)
    news_service = next((s for s in services if s.get("id") == "news"), None)
    if news_service is not None:
        if news_obs_error:
            warnings.append(f"news observability: {news_obs_error}")
            news_service["observability"] = {"status": "access_unknown", "url": NEWS_OBSERVABILITY_URL}
        else:
            observed_at = news_obs.get("observed_at") if isinstance(news_obs, dict) else None
            obs_age = None
            if observed_at:
                try:
                    obs_age = round((now - datetime.fromisoformat(observed_at.replace("Z", "+00:00"))).total_seconds() / 3600, 2)
                except ValueError:
                    pass
            stages = (news_obs or {}).get("stages", {}) if isinstance(news_obs, dict) else {}
            news_service["observability"] = {
                "status": "observed",
                "observed_at": observed_at,
                "age_hours": obs_age,
                "run_id": (news_obs or {}).get("run_id"),
                "stages": stages,
                "counts": (news_obs or {}).get("counts", {}),
                "artifacts": (news_obs or {}).get("artifacts", {}),
                "url": NEWS_OBSERVABILITY_URL,
            }
            record_observed_news_ingest(news_obs)
            if obs_age is None or obs_age > MAX_AGE_HOURS["news"]:
                news_service["status"] = "degraded"
                news_service["label"] = "원장 신선도 경과"
                news_service["detail"] = "NewsBoard 실행 원장이 최신 수집 회차와 연결되지 않았습니다"
            elif any((stages.get(k) or {}).get("status") in {"failed", "degraded", "unknown"} for k in ("collect", "analyze", "quality")):
                news_service["status"] = "degraded"
                news_service["label"] = "데이터 단계 주의"
                news_service["detail"] = "실행 원장에 수집·분석·품질 단계 주의가 기록되어 있습니다"
            elif (stages.get("publish") or {}).get("status") != "success":
                news_service["status"] = "degraded"
                news_service["label"] = "게시 확인 대기"
                news_service["detail"] = "수집 원장은 있으나 data 게시 확인이 완료되지 않았습니다"

    # Other services can expose the same public contract. A workflow result is
    # never promoted to a healthy collector without a successful collect stage.
    for service in services:
        service_id = service.get("id")
        if service_id == "news" or service_id not in OBSERVABILITY_SOURCES:
            continue
        source_url = OBSERVABILITY_SOURCES[service_id]
        observability, source_error = get_public_json(source_url)
        if source_error or not isinstance(observability, dict):
            continue
        stages = observability.get("stages") or {}
        collect_stage = stages.get("collect") or {}
        collect_status = str(collect_stage.get("status") or "unknown")
        service["observability"] = {
            "status": "observed",
            "observed_at": observability.get("observed_at"),
            "run_id": observability.get("run_id"),
            "stages": stages,
            "counts": observability.get("counts") or {},
            "url": source_url,
        }
        if collect_status not in {"success", "observed"}:
            service["status"] = "degraded"
            service["label"] = "수집 미구현" if collect_status == "not_implemented" else "수집 미관측"
            service["detail"] = str(observability.get("note") or "수집 원장에 성공 근거가 없습니다")
            service["next"] = "원천 수집기와 검증 원장 연결"

    # A green workflow is operational evidence only.  It cannot establish that
    # a source was fetched, data was persisted, or quality passed.
    for service in services:
        if service.get("observability"):
            continue
        service["status"] = "degraded"
        service["label"] = "수집 미관측"
        service["detail"] = "GitHub Actions 실행 기록만 있고 실제 수집·저장 원장이 없습니다"
        service["next"] = "수집기에서 observability/latest.json 발행"
    incidents.sort(key=lambda x: (0 if x["severity"] == "high" else 1, x.get("updated_at") or ""), reverse=False)
    healthy = sum(s["status"] == "healthy" for s in services)
    degraded = sum(s["status"] == "degraded" for s in services)
    snapshot = {
        "schema_version": "2.0.0", "generated_at": now.isoformat(), "source": "github-actions-live",
        "overall": {"status": "attention" if degraded else "healthy", "label": f"운영 주의 {degraded}건" if degraded else "전체 정상", "healthy": healthy, "degraded": degraded, "blocked": 0, "note": "GitHub Actions·열린 이슈를 5분 주기로 집계합니다."},
        "services": services, "incidents": incidents[:30],
        "checks": [{"name": "GitHub API", "state": "pass" if not warnings else "warn", "value": f"{len(services)}개 저장소 · {len(warnings)}개 경고"}, {"name": "실시간 집계", "state": "pass", "value": "5분 주기 Actions"}],
        "warnings": warnings,
    }
    # Fail closed on authentication/rate-limit outages. Do not overwrite a
    # previously valid snapshot with an all-unknown red screen.
    if services and warnings and all(s["label"] == "접근 확인" for s in services):
        print("GitHub API 접근 실패: 기존 live_operations.json을 보존합니다.")
        return 2
    old = json.loads(OUT.read_text()) if OUT.exists() else None
    comparable = lambda x: {k: v for k, v in x.items() if k != "generated_at"}
    if old and comparable(old) == comparable(snapshot):
        record_workflow_events(services)
        return 0
    OUT.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
    record_workflow_events(services)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
