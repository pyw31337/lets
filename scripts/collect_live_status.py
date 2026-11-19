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
    ("culture", "렛츠컬처"), ("news", "렛츠뉴스"),
    ("macmini-workflow-handoff", "Mac mini handoff"), ("cctv", "렛츠뷰"),
    ("calendar", "렛츠캘린더"), ("camp", "렛츠캠핑"), ("meat", "렛츠미트"),
    ("metro", "렛츠메트로"), ("pick", "렛츠픽"), ("buy", "렛츠바이"),
    ("hair", "렛츠헤어"), ("coupang", "렛츠쿠팡"), ("all", "포트폴리오 허브"),
    ("yasu", "렛츠야스"), ("cultureflow-ai-test", "CultureFlow AI test"),
]
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "data/live_operations.json"


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
        latest = run_items[0] if run_items else {}
        latest_time = latest.get("updated_at") or latest.get("created_at")
        conclusion = latest.get("conclusion")
        recent_failures = [r for r in run_items if r.get("conclusion") in ("failure", "cancelled", "timed_out") and r.get("updated_at") and (now - datetime.fromisoformat(r["updated_at"].replace("Z", "+00:00"))).total_seconds() < 86400]
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
        if open_items:
            # Open issues are surfaced as events, but do not make every service
            # red: many repositories intentionally keep planning issues open.
            for issue in open_items[:3]:
                incidents.append({"severity": "medium", "title": f"{repo} 이슈 #{issue['number']}: {issue['title']}", "service": name, "why": "GitHub에서 열린 이슈", "action": "이슈 상태 확인", "href": issue["html_url"], "updated_at": issue.get("updated_at")})
        for run in recent_failures[:2]:
            incidents.append({"severity": "high", "title": f"{repo} workflow 실패: {run.get('name', 'workflow')}", "service": name, "why": f"{run.get('conclusion')} · {run.get('head_branch', 'main')}", "action": "실패 로그 확인", "href": run.get("html_url", f"https://github.com/{OWNER}/{repo}/actions"), "updated_at": run.get("updated_at")})
        services.append({
            "id": repo, "name": name, "status": status, "label": label,
            "detail": detail, "updated_at": iso(latest_time),
            "url": f"https://github.com/{OWNER}/{repo}/actions",
            "repo": f"https://github.com/{OWNER}/{repo}", "next": next_action,
            "latest_run": {"name": latest.get("name"), "conclusion": conclusion, "status": latest.get("status"), "url": latest.get("html_url")},
            "open_issues": len(open_items),
        })
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
    old = json.loads(OUT.read_text()) if OUT.exists() else None
    comparable = lambda x: {k: v for k, v in x.items() if k != "generated_at"}
    if old and comparable(old) == comparable(snapshot):
        return 0
    OUT.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
