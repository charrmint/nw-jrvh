"""Shared live-form inventory resolver backed by OneKare's Databricks endpoint.

Browser workers pass only semantic form inventories and the canonical key catalog
to this resolver. Parent answer values and credentials never enter model prompts.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
from typing import Any
from urllib.request import Request, urlopen


class LiveMappingResolver:
    def __init__(self, request: dict[str, Any]):
        self.current = request.get("current_mappings", {})
        self.catalog = request["canonical_catalog"]
        self.policy = request["allowed_default_policy"]
        self.changes: list[dict[str, Any]] = []

    async def resolve(self, *, step: str, inventory: dict[str, Any]) -> dict[str, Any]:
        fingerprint = self._fingerprint(inventory)
        current = self.current.get(step)
        if current and current["inventory_fingerprint"] == fingerprint:
            return current

        proposal = await asyncio.to_thread(self._suggest, inventory, current)
        validated = self._validate(inventory, proposal)
        change = {
            "step": step,
            "inventory": inventory,
            "inventory_fingerprint": fingerprint,
            **validated,
        }
        self.changes.append(change)
        self.current[step] = change
        return change

    def _suggest(self, inventory: dict[str, Any], current: dict[str, Any] | None) -> dict[str, Any]:
        host = os.environ["DATABRICKS_HOST"].rstrip("/")
        endpoint = os.environ["DATABRICKS_MODEL_ENDPOINT"]
        body = {
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "Return strict JSON with mappings, defaults, and blockers. Map only to canonical "
                        "catalog keys. Defaults may target only observed controls and observed choices. "
                        "Provider-specific priority and marketing SMS may default to No. Never default "
                        "eligibility to Yes. Do not infer parent answers."
                    ),
                },
                {
                    "role": "user",
                    "content": json.dumps(
                        {
                            "inventory": inventory,
                            "canonical_catalog": self.catalog,
                            "previous_inventory": current.get("inventory") if current else None,
                            "allowed_default_policy": self.policy,
                        },
                        separators=(",", ":"),
                    ),
                },
            ],
            "temperature": 0.0,
            "max_tokens": 3000,
        }
        http_request = Request(
            f"{host}/serving-endpoints/{endpoint}/invocations",
            data=json.dumps(body).encode(),
            headers={
                "Authorization": f"Bearer {os.environ['DATABRICKS_TOKEN']}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urlopen(http_request, timeout=120) as response:
            payload = json.load(response)
        content = (
            payload.get("choices", [{}])[0].get("message", {}).get("content")
            or payload.get("predictions", [{}])[0].get("content")
        )
        if isinstance(content, str):
            content = content.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
            return json.loads(content)
        return content or {"mappings": {}, "defaults": {}, "blockers": ["empty_model_response"]}

    def _validate(self, inventory: dict[str, Any], proposal: dict[str, Any]) -> dict[str, Any]:
        fields = {field["key"]: field for field in inventory.get("fields", [])}
        catalog = set(self.catalog)
        warnings: list[str] = []
        mappings: dict[str, str] = {}
        aliases = {
            "child.birthdate_or_estimated": "child.date_of_birth",
            "school.catchment.cascade_or_inman": "school.catchment",
            "parent.birthdate": "parent.date_of_birth",
            "parent.mobile_phone": "parent.local_phone",
            "parent.second_guardian": "parent.second_guardian_name",
            "child.age_category": "child.date_of_birth",
            "child.extra_needs": "child.support_required",
            "program_type": "daycare.external_program_id",
            "centres": "daycare.external_location_id",
        }
        for live_key, canonical_key in proposal.get("mappings", {}).items():
            if not isinstance(live_key, str) or not isinstance(canonical_key, str):
                warnings.append("discarded_non_string_mapping")
                continue
            if live_key in catalog and canonical_key in fields:
                live_key, canonical_key = canonical_key, live_key
            if live_key.startswith("priority.") and canonical_key in {
                "priority.affiliations",
                "priority.categories",
            }:
                warnings.append(f"discarded_branded_priority_mapping:{live_key}")
                continue
            if live_key == "parent.marketing_sms":
                warnings.append("discarded_marketing_sms_mapping")
                continue
            if live_key not in fields or canonical_key not in catalog:
                warnings.append(f"discarded_invalid_mapping:{live_key}")
                continue
            mappings[live_key] = canonical_key

        for live_key in fields:
            if live_key in catalog:
                mappings[live_key] = live_key
            elif live_key in aliases and aliases[live_key] in catalog:
                mappings[live_key] = aliases[live_key]

        defaults: dict[str, str] = {}
        for live_key, value in proposal.get("defaults", {}).items():
            field = fields.get(live_key)
            if not field:
                if live_key == "provider_specific_priority" and value == self.policy.get(live_key):
                    for key, candidate in fields.items():
                        if key.startswith("priority.") and value in candidate.get("choices", []):
                            defaults[key] = value
                    continue
                if live_key == "marketing_sms" and value == self.policy.get(live_key):
                    sms = fields.get("parent.marketing_sms")
                    if sms and sms.get("type") == "checkbox" and value == "No":
                        defaults["parent.marketing_sms"] = value
                    continue
                warnings.append(f"discarded_unobserved_default:{live_key}")
                continue
            kind = "marketing_sms" if "sms" in live_key else "provider_specific_priority"
            choices = field.get("choices", [])
            boolean_no = field.get("type") == "checkbox" and value == "No"
            if self.policy.get(kind) != value or (value not in choices and not boolean_no):
                warnings.append(f"discarded_disallowed_default:{live_key}")
                continue
            defaults[live_key] = value

        if self.policy.get("provider_specific_priority") == "No":
            for key, candidate in fields.items():
                if key.startswith("priority.") and "No" in candidate.get("choices", []):
                    defaults[key] = "No"
        sms = fields.get("parent.marketing_sms")
        if self.policy.get("marketing_sms") == "No" and sms and sms.get("type") == "checkbox":
            defaults["parent.marketing_sms"] = "No"
        return {"mapping": mappings, "defaults": defaults, "warnings": warnings}

    @staticmethod
    def _fingerprint(inventory: dict[str, Any]) -> str:
        canonical = json.dumps(inventory, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(canonical.encode()).hexdigest()
