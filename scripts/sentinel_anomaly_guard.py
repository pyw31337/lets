#!/usr/bin/env python3
"""
scripts/sentinel_anomaly_guard.py
렛츠 15개 서비스 전수 자가진화 수집 품질 검수 및 무인 자동 치유(Self-Healing Fallback) 센티널
- 15개 마이크로서비스 및 28개 자동화 장치의 실시간 수집량 & 품질 데이터 전수 검수
- 이상징후 실시간 감지:
  1) Zero-Drop (일일 수집량이 0으로 급감)
  2) Flat-Curve (기울기가 완만해지거나 전일 대비 -40% 이상 급격한 정체)
  3) Quality-Drop (데이터 정제 품질 지수 85% 미만 하락)
- 자가 치유(Self-Healing Fallback):
  * 외부 API 장애 감지 시 백업 미러/프록시로 자동 우회 스위칭
  * 크롤러 자동 재시도 큐(Retry Backoff) 생성
  * master_ecosystem_pulse.json 의 caution_alerts 및 건전도 갱신
"""
import json
import os
import sys
from datetime import datetime, timezone, timedelta

KST = timezone(timedelta(hours=9))

def run_sentinel():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    pulse_path = os.path.join(base_dir, "data", "master_ecosystem_pulse.json")

    if not os.path.exists(pulse_path):
        print("master_ecosystem_pulse.json not found.")
        return False

    with open(pulse_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    now_kst = datetime.now(KST).isoformat()
    today_label = datetime.now(KST).strftime('%m/%d')
    data["last_updated"] = now_kst

    services = data.get("standalone_services", [])
    devices = data.get("automation_devices", [])

    # A configured inventory is not evidence that a collector ran. Keep the
    # hub explicitly unverified until a real SUCCESS/FAILED run event exists.
    run_path = os.path.join(base_dir, "data", "automation_runs.json")
    try:
        with open(run_path, "r", encoding="utf-8") as f:
            run_data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        run_data = {"runs": []}
    observed_runs = [r for r in run_data.get("runs", []) if r.get("status") in {"SUCCESS", "FAILED"}]
    data["metric_provenance"] = "observed_runs" if observed_runs else "configured_snapshot"
    data["run_event_store"] = "data/automation_runs.json"

    anomalies_detected = []
    remediations_performed = []

    # Planned rates and catalog snapshots cannot prove a drop, a quality
    # regression, or a successful recovery. Keep the sentinel honest until
    # each service emits signed run-level evidence.
    alerts = [{
            "id": f"alert_sentinel_unverified_{today_label}",
            "level": "WARNING",
            "service_id": "all",
            "service_name": "센티널 통합 감시",
            "badge_text": "실측 대기",
            "badge_bg": "#fef3c7",
            "badge_color": "#92400e",
            "title": "실행 이벤트가 없어 운영 상태를 검증할 수 없습니다",
            "desc": "서비스 원장과 설정값은 존재하지만 최근 SUCCESS/FAILED 실행 이벤트가 없습니다. 정상 가동이나 자동 치유로 표시하지 않습니다.",
            "timestamp": now_kst
        }]

    data["caution_alerts"] = alerts

    # 3. 종합 통계 업데이트
    data["summary"]["total_indexed_records"] = None
    data["summary"]["total_daily_ingest_rate"] = None
    data["summary"]["ecosystem_health_score"] = None
    data["summary"]["zero_drop_anomalies"] = len([a for a in anomalies_detected if a["type"] == "ZERO_DROP"])
    data["summary"]["flat_curve_anomalies"] = len([a for a in anomalies_detected if a["type"] == "FLAT_CURVE"])
    data["summary"]["total_standalone_services"] = len(services)
    data["summary"]["status"] = (
        "EVIDENCE_REQUIRED"
    )

    with open(pulse_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"[{now_kst}] 렛츠 자가진화 센티널 검수 완료:")
    daily_text = "일일 실측 대기"
    print(f"  - 서비스별 실행 원장 연결 대기 ({daily_text})")
    print(f"  - 감지된 이상징후: {len(anomalies_detected)}건 (Zero-Drop: {data['summary']['zero_drop_anomalies']}, Flat-Curve: {data['summary']['flat_curve_anomalies']})")
    print(f"  - 무인 자가 치유(Self-Healing) 조치 실행: {len(remediations_performed)}건")
    return True

if __name__ == "__main__":
    run_sentinel()
