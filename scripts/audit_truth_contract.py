#!/usr/bin/env python3
"""Run a fail-closed self-audit over LetsHub's public truth contract.

This does not promote configured or stale values to live data. It records the
gaps so the next dashboard refresh and the next agent pass see the same facts.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


registry = load(ROOT / "data/observability/source_registry.json", {"sources": {}})
validation = load(ROOT / "data/observability/source_validation.json", {"services": []})
live = load(ROOT / "data/live_operations.json", {"services": []})
pulse = load(ROOT / "data/collection_pulse.json", {})
issues = []

source_ids = set((registry.get("sources") or {}).keys())
validation_ids = {item.get("service_id") for item in validation.get("services", [])}
live_ids = {item.get("id") for item in live.get("services", [])}
for missing in sorted(source_ids - validation_ids):
    issues.append({"severity": "high", "kind": "source_not_validated", "service_id": missing})
for missing in sorted(source_ids - live_ids):
    issues.append({"severity": "high", "kind": "source_not_in_live_snapshot", "service_id": missing})
for item in validation.get("services", []):
    if item.get("status") in {"not_configured", "unreachable"}:
        issues.append({"severity": "high", "kind": item.get("status"), "service_id": item.get("service_id"), "detail": item.get("error")})
for item in live.get("services", []):
    if item.get("status") == "healthy" and not item.get("observability"):
        issues.append({"severity": "high", "kind": "healthy_without_observability", "service_id": item.get("id")})

overall = pulse.get("overall") or {}
if overall.get("volume_evidence") != "observed":
    issues.append({"severity": "high", "kind": "collection_volume_not_observed"})

master = load(ROOT / "data/master_ecosystem_pulse.json", {})
if master.get("metric_provenance") != "observed_runs":
    issues.append({"severity": "medium", "kind": "showcase_uses_configured_snapshot", "detail": master.get("metric_provenance")})

lifecycle = load(ROOT / "data/service_lifecycle.json", {"services": {}})
active_ids = source_ids | live_ids
for service_id, record in (lifecycle.get("services") or {}).items():
    if record.get("status") == "retired" and service_id in active_ids:
        issues.append({"severity": "high", "kind": "retired_service_active", "service_id": service_id, "successor": record.get("successor")})

result = {
    "schema": "lets_truth_audit_v1",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "status": "attention" if issues else "pass",
    "summary": {
        "sources": len(source_ids),
        "validated": len(validation_ids),
        "live_services": len(live_ids),
        "issues": len(issues),
        "high": sum(issue["severity"] == "high" for issue in issues),
        "medium": sum(issue["severity"] == "medium" for issue in issues),
    },
    "issues": issues,
    "rule": "Configured values, workflow success, and snapshots never count as daily live volume without a source-backed observability record.",
}
(ROOT / "data/observability/self_audit.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps(result["summary"], ensure_ascii=False))
