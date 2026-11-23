#!/usr/bin/env python3
"""Validate every service's public evidence contract without inventing metrics."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
registry = json.loads((ROOT / "data/observability/source_registry.json").read_text(encoding="utf-8"))
services = []
for service_id, url in registry["sources"].items():
    item = {"service_id": service_id, "url": url, "status": "not_configured", "observed_at": None, "run_id": None, "counts": {}}
    if url:
        try:
            req = Request(f"{url}?t={int(datetime.now(timezone.utc).timestamp() // 60)}", headers={"Accept": "application/json", "User-Agent": "letshub-observability-validator"})
            with urlopen(req, timeout=20) as response:
                payload = json.loads(response.read().decode("utf-8"))
            stages = payload.get("stages") or {}
            collect = stages.get("collect") or {}
            quality = stages.get("quality") or {}
            item.update({"status": "observed" if collect.get("status") in {"success", "observed"} else "degraded", "observed_at": payload.get("observed_at"), "run_id": payload.get("run_id"), "counts": payload.get("counts") or {}, "collect": collect.get("status"), "quality": quality.get("status")})
        except Exception as exc:
            item.update({"status": "unreachable", "error": str(exc)})
    services.append(item)
result = {"schema": "lets_observability_validation_v1", "generated_at": datetime.now(timezone.utc).isoformat(), "services": services, "observed": sum(s["status"] == "observed" for s in services), "not_configured": sum(s["status"] == "not_configured" for s in services), "degraded": sum(s["status"] in {"degraded", "unreachable"} for s in services)}
(ROOT / "data/observability/source_validation.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: result[k] for k in ("observed", "not_configured", "degraded")}, ensure_ascii=False))
