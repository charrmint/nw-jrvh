"""Fill Beyond Care's public waitlist and optionally submit it."""

from __future__ import annotations

import asyncio
import json
import os
import sys
import traceback
from typing import Any

from playwright.async_api import async_playwright

from beyond_care_waitlist import (
    BeyondCareWaitlist,
    EligibilityBlocked,
    FinalSubmissionForbidden,
    VerificationChallenge,
)
from live_mapping_resolver import LiveMappingResolver


async def run(request: dict[str, Any]) -> dict[str, Any]:
    resolver = LiveMappingResolver(request)
    result: dict[str, Any] = {
        "status": "failed",
        "reached_submit_ready": False,
        "submitted": False,
        "submission_confirmed": False,
        "submission_attempted": False,
        "mapping_changes": [],
    }
    stage = "launch"
    adapter = None
    page = None
    write_requests: list[str] = []
    try:
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=request.get("headless", True))
            context = await browser.new_context()
            page = await context.new_page()
            page.on(
                "request",
                lambda outgoing: write_requests.append(outgoing.url)
                if outgoing.method in {"POST", "PUT", "PATCH", "DELETE"}
                else None,
            )
            adapter = BeyondCareWaitlist(
                page,
                resolver,
                experiment=not request.get("submit_enabled", False),
                debug_screenshot=request.get("debug_screenshot"),
            )
            stage = "inspect"
            resolved = await adapter.open_and_inspect()
            stage = "fill"
            try:
                await adapter.fill(request["snapshot"], resolved)
                stage = "persistence"
                persistence = await adapter.persistence_probe()
                if not persistence["form_valid"]:
                    raise RuntimeError("The live waitlist form is invalid before submission")
                result.update(reached_submit_ready=True, persistence=persistence)
                stage = "submit_guard"
                if request.get("submit_enabled"):
                    await adapter._guard_verification()
                    result["submission_attempted"] = True
                    stage = "submit"
                    await adapter.submit_application()
                    stage = "confirmation"
                    await page.get_by_text("Application Submitted!", exact=True).wait_for(
                        state="visible", timeout=15_000
                    )
                    result.update(status="submitted", submitted=True, submission_confirmed=True)
                else:
                    try:
                        await adapter.submit_application()
                    except FinalSubmissionForbidden:
                        pass
                    result["status"] = "filled_unsent"
            except EligibilityBlocked as error:
                persistence = await adapter.persistence_probe()
                result.update(
                    status="eligibility_blocked",
                    blocker="age_category",
                    blocker_detail=str(error),
                    persistence=persistence,
                )
            result.update(
                filled_fields=adapter.filled_fields,
                observed_field_keys=[field["key"] for field in adapter.inventory.get("fields", [])],
                mapping_reused=adapter.mapping_reused,
                pre_submit_form_write_requests=[
                    url for url in write_requests if "/api/forms/waitlist" in url
                ],
                background_write_request_count=len(
                    [url for url in write_requests if "/api/forms/waitlist" not in url]
                ),
            )
            if request.get("debug_screenshot"):
                await page.screenshot(path=request["debug_screenshot"], full_page=False)
            await context.close()
            await browser.close()
    except VerificationChallenge as error:
        result.update(status="verification_required", blocker="verification", blocker_detail=str(error))
    except Exception as error:
        if result["submission_attempted"]:
            result["status"] = "submission_uncertain"
        result["error_type"] = type(error).__name__
        result["error_stage"] = stage
        result["error_detail"] = adapter.safe_stage if adapter else None
        frame = traceback.extract_tb(error.__traceback__)[-1]
        result["error_location"] = {
            "file": os.path.basename(frame.filename),
            "line": frame.lineno,
            "function": frame.name,
        }
    result["mapping_changes"] = resolver.changes
    return result


def main() -> None:
    request = json.loads(sys.stdin.read())
    print(json.dumps(asyncio.run(run(request)), separators=(",", ":")))


if __name__ == "__main__":
    main()
