#!/usr/bin/env python3
"""Turn truth-audit findings into a deterministic remediation plan."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
audit = json.loads((ROOT / "data/observability/self_audit.json").read_text(encoding="utf-8"))
actions = []
for issue in audit.get("issues", []):
    service_id = issue.get("service_id") or "all"
    kind = issue.get("kind")
    if kind == "not_configured":
        action, reason = "connect_public_observability_source", "수집기와 공개 observability/latest.json 연결이 없습니다."
    elif kind == "unreachable":
        action, reason = "verify_source_endpoint_and_freshness", "등록된 원장을 읽을 수 없습니다."
    elif kind == "healthy_without_observability":
        action, reason = "demote_unproven_health_status", "실행 상태만 있고 수집 원장 근거가 없습니다."
    elif kind == "collection_volume_not_observed":
        action, reason = "connect_increment_event_contract", "일일 적재량을 계산할 수 있는 증분 이벤트가 없습니다."
    else:
        action, reason = "inspect_truth_contract", issue.get("detail") or "원장 계약을 점검해야 합니다."
    actions.append({"service_id": service_id, "priority": issue.get("severity", "medium"), "action": action, "reason": reason, "safe_next_step": "실제 원장·품질 근거를 연결한 뒤 재검증"})

result = {
    "schema": "lets_ops_action_plan_v1",
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "status": "attention" if actions else "clear",
    "actions": actions,
    "policy": "자동 결정은 진단과 추적까지만 수행하며, 원천 서비스 데이터나 수집량을 임의로 변경하지 않습니다.",
}
(ROOT / "data/observability/action_plan.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"status": result["status"], "actions": len(actions)}, ensure_ascii=False))
