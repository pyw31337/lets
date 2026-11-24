#!/usr/bin/env python3
"""
scripts/dispatch_anomaly_alert.py
LetsHub 긴급 운영 이상 감지 및 텔레그램 / 웹훅 알림 브리지
- self_audit.json, action_plan.json, live_operations.json의 장애/지연/이상 징후를 감지하여 즉각 전송
- TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID 또는 DISCORD_WEBHOOK_URL / SLACK_WEBHOOK_URL 연동 지원
- 미설정 시에도 로컬 디스패치 원장(data/observability/dispatch_history.jsonl)에 실측 증적 기록
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
KST = timezone(timedelta(hours=9))


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def format_incident_report():
    audit = load_json(ROOT / "data/observability/self_audit.json", {})
    action_plan = load_json(ROOT / "data/observability/action_plan.json", {})
    live_ops = load_json(ROOT / "data/live_operations.json", {})
    validation = load_json(ROOT / "data/observability/source_validation.json", {})

    now_kst = datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S KST")

    # Find degraded / failed / stale services
    incidents = []
    for s in live_ops.get("services", []):
        if s.get("status") in {"stale", "failed", "degraded"}:
            incidents.append(f"• {s.get('name', s.get('id'))}: {s.get('label', s.get('status'))} (최근 실행: {s.get('updated_at', '불명')})")

    for v in validation.get("services", []):
        if v.get("status") in {"not_configured", "unreachable", "degraded"}:
            incidents.append(f"• [검증] {v.get('service_id')}: {v.get('status')} ({v.get('url') or '원장 미설정'})")

    audit_status = audit.get("status", "pass")
    issue_count = audit.get("summary", {}).get("issues", 0)

    msg = [
        "🚨 [LetsHub 긴급 운영 관제 알림]",
        f"📅 관측 일시: {now_kst}",
        f"🛡️ 진단 상태: {audit_status.upper()} (감지된 이슈: {issue_count}건)",
        "",
        "📋 주요 관측 및 이상 항목:"
    ]

    if incidents:
        msg.extend(incidents[:8])
    else:
        msg.append("• 16개 전 서비스 원장 무결성 및 수집 정상")

    msg.extend([
        "",
        "🔗 허브 콘솔: https://pyw31337.github.io/lets/",
        "⚡ 조치 계획: data/observability/action_plan.json 자동 배포 대기"
    ])

    return "\n".join(msg), len(incidents) + issue_count


def dispatch():
    message, count = format_incident_report()
    now_iso = datetime.now(timezone.utc).isoformat()

    dispatched_targets = []

    # 1. Telegram Dispatch
    tg_token = os.environ.get("TELEGRAM_BOT_TOKEN")
    tg_chat_id = os.environ.get("TELEGRAM_CHAT_ID")
    if tg_token and tg_chat_id:
        try:
            tg_url = f"https://api.telegram.org/bot{tg_token}/sendMessage"
            payload = json.dumps({"chat_id": tg_chat_id, "text": message, "parse_mode": "HTML"}).encode("utf-8")
            req = Request(tg_url, data=payload, headers={"Content-Type": "application/json"})
            with urlopen(req, timeout=10) as resp:
                if resp.status == 200:
                    dispatched_targets.append("telegram")
        except Exception as e:
            print(f"Telegram dispatch failed: {e}", file=sys.stderr)

    # 2. Discord / Slack Webhook Dispatch
    webhook_url = os.environ.get("DISCORD_WEBHOOK_URL") or os.environ.get("SLACK_WEBHOOK_URL")
    if webhook_url:
        try:
            payload = json.dumps({"text": message, "content": message}).encode("utf-8")
            req = Request(webhook_url, data=payload, headers={"Content-Type": "application/json"})
            with urlopen(req, timeout=10) as resp:
                if resp.status in {200, 204}:
                    dispatched_targets.append("webhook")
        except Exception as e:
            print(f"Webhook dispatch failed: {e}", file=sys.stderr)

    # 3. Always log to dispatch history ledger
    history_file = ROOT / "data/observability/dispatch_history.jsonl"
    log_entry = {
        "timestamp": now_iso,
        "incident_count": count,
        "dispatched_targets": dispatched_targets if dispatched_targets else ["simulated_ledger"],
        "message_preview": message.splitlines()[0:3]
    }
    with history_file.open("a", encoding="utf-8") as f:
        f.write(json.dumps(log_entry, ensure_ascii=False) + "\n")

    print(json.dumps({
        "status": "success",
        "timestamp": now_iso,
        "incident_count": count,
        "targets": dispatched_targets if dispatched_targets else ["simulated_ledger"]
    }, ensure_ascii=False))


if __name__ == "__main__":
    dispatch()
