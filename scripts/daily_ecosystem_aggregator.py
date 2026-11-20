#!/usr/bin/env python3
"""
scripts/daily_ecosystem_aggregator.py
렛츠 통합 관제 대시보드 24/7 무인 자동 생태계 집계 & 이상징후 센티널 연동 파이프라인
- pyw31337 산하 15개 전체 레포지토리의 수집량, 품질 점수, 이상징후 실시간 종합 집계
- sentinel_anomaly_guard 연계 무인 자동 검수
"""
import json
import os
import subprocess
from datetime import datetime, timezone, timedelta

KST = timezone(timedelta(hours=9))

def run_aggregation():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pulse_path = os.path.join(base_dir, "data", "master_ecosystem_pulse.json")

    if not os.path.exists(pulse_path):
        print("master_ecosystem_pulse.json not found.")
        return

    with open(pulse_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    now_kst = datetime.now(KST).isoformat()
    data["last_updated"] = now_kst

    # 1. Use observed run events when available. Never add configured rates to
    # totals: a planned rate is not proof that a source was fetched or stored.
    services = data.get("standalone_services", [])
    run_path = os.path.join(base_dir, "data", "automation_runs.json")
    run_data = {"runs": []}
    if os.path.exists(run_path):
        with open(run_path, "r", encoding="utf-8") as f:
            run_data = json.load(f)
    runs = [r for r in run_data.get("runs", []) if r.get("status") == "SUCCESS"]

    data["metric_provenance"] = "observed_runs" if runs else "configured_snapshot"
    data["run_event_store"] = "data/automation_runs.json"
    data["summary"]["observed_run_count"] = len(runs)
    if runs:
        data["summary"]["total_daily_ingest_rate"] = sum(
            int(r.get("observed", {}).get("count", 0) or 0)
            for r in runs if r.get("stage") == "INGEST"
        )
        data["summary"]["total_daily_analyze_rate"] = sum(
            int(r.get("observed", {}).get("count", 0) or 0)
            for r in runs if r.get("stage") == "ANALYZE"
        )
    else:
        # Keep the legacy snapshot stable and visibly marked as configured.
        data["summary"]["configured_daily_ingest_rate"] = sum(
            s.get("daily_ingest_rate", 0) for s in services
        )
        data["summary"]["configured_daily_analyze_rate"] = data["summary"].get(
            "total_daily_analyze_rate", 0
        )
        data["summary"]["total_daily_ingest_rate"] = None
        data["summary"]["total_daily_analyze_rate"] = None
    # The legacy inventory has planning snapshots, not independently verified
    # cumulative storage totals or health scores. Never recast them as facts.
    data["summary"]["total_indexed_records"] = None
    data["summary"]["ecosystem_health_score"] = None
    data["summary"]["cumulative_evidence"] = "not_connected"
    data["summary"]["quality_evidence"] = "not_connected"

    with open(pulse_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    observed_label = data["summary"].get("total_daily_ingest_rate")
    daily_text = f"{observed_label:,}건 실측" if isinstance(observed_label, (int, float)) else "실측 대기"
    print(f"[{now_kst}] 렛츠 통합 관제 허브 집계 완료: 누적 실측 대기, 일일 수집 {daily_text}")


if __name__ == "__main__":
    run_aggregation()
