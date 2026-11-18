#!/usr/bin/env python3
"""Audit the master pulse before it is used as an operational dashboard.

The audit intentionally distinguishes configured/planned values from observed
run artifacts. It does not mutate the pulse file.
"""
from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PULSE = ROOT / "data" / "master_ecosystem_pulse.json"


def main() -> int:
    data = json.loads(PULSE.read_text(encoding="utf-8"))
    summary = data.get("summary", {})
    services = data.get("standalone_services", [])
    devices = data.get("automation_devices", [])

    report = {
        "summary_device_count": summary.get("total_automation_devices"),
        "observed_device_count": len(devices),
        "summary_service_count": summary.get("total_standalone_services"),
        "observed_service_count": len(services),
        "device_count_match": summary.get("total_automation_devices") == len(devices),
        "service_count_match": summary.get("total_standalone_services") == len(services),
        "devices_without_metrics": [d.get("id") for d in devices if not d.get("metrics")],
        "devices_without_script": [d.get("id") for d in devices if not d.get("script")],
        "services_without_health": [s.get("id") for s in services if s.get("health_score") is None],
        "stage_counts": {},
    }
    for device in devices:
        stage = device.get("pipeline_stage") or "UNSPECIFIED"
        report["stage_counts"][stage] = report["stage_counts"].get(stage, 0) + 1

    # These are informational only: a configured rate is not an observed run.
    report["configured_daily_ingest_rate"] = sum(
        float(s.get("daily_ingest_rate", 0) or 0) for s in services
    )
    report["configured_daily_analyze_rate"] = float(summary.get("total_daily_analyze_rate", 0) or 0)
    report["warning"] = (
        "master pulse contains configured rates; observed run events are required "
        "before presenting completion as actual"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report["device_count_match"] and report["service_count_match"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
