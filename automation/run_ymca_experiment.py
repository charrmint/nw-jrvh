"""Run the YMCA adapter from one JSON request read on stdin.

The request contains credentials and answers and therefore must only arrive over
an anonymous pipe. Output contains observations/mappings and safe status data,
never credentials or answer values.
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import sys
import traceback
from typing import Any

from playwright.async_api import async_playwright

from live_mapping_resolver import LiveMappingResolver
from ymca_child_care_waitlist import FinalSubmissionForbidden, YmcaChildCareWaitlist


async def run(request: dict[str, Any]) -> dict[str, Any]:
    resolver = LiveMappingResolver(request)
    result: dict[str, Any] = {
        "status": "failed",
        "reached_review": False,
        "submitted": False,
        "submission_confirmed": False,
        "submission_attempted": False,
        "mapping_changes": [],
    }
    stage = "launch"
    adapter = None
    page = None
    try:
        async with async_playwright() as playwright:
            browser = await playwright.chromium.launch(headless=request.get("headless", True))
            context = await browser.new_context()
            page = await context.new_page()
            adapter = YmcaChildCareWaitlist(
                page,
                resolver,
                experiment=not request.get("submit_enabled", False),
                allow_child_creation=True,
                debug_screenshot=request.get("debug_screenshot"),
            )
            stage = "login"
            await adapter.login(
                username=request["credential"]["username"],
                password=request["credential"]["password"],
            )
            if request.get("diagnostic") == "waitlist_dashboard":
                waitlist_link = page.get_by_role("link", name="Waitlist", exact=True)
                waitlist_href = await waitlist_link.get_attribute("href")
                await waitlist_link.click()
                await page.wait_for_load_state("domcontentloaded")
                if request.get("debug_screenshot"):
                    await page.screenshot(path=request["debug_screenshot"], full_page=False)
                return {
                    "status": "diagnostic_complete",
                    "reached_review": False,
                    "mapping_changes": resolver.changes,
                    "diagnostic_data": {"waitlist_href": waitlist_href},
                }
            stage = "choose_program"
            target = await adapter.choose_first_compatible_program(
                program_text=request["program_text"],
                centre_text=request.get("centre_text"),
                fallback_location_id=request["target"]["external_location_id"],
                fallback_program_id=request["target"]["external_program_id"],
            )
            stage = "your_child"
            await adapter.fill_child_step(request["snapshot"])
            stage = "your_family"
            await adapter.fill_family_step(request["snapshot"])
            stage = "locations"
            await adapter.keep_first_location_and_open_review()
            result["reached_review"] = True
            stage = "review_guard"
            if request.get("submit_enabled"):
                result["submission_attempted"] = True
                stage = "submit"
                await adapter.submit_application()
                stage = "confirmation"
                await page.get_by_role("heading", name="Review and submit").wait_for(
                    state="hidden", timeout=15_000
                )
                confirmation = page.get_by_text(
                    re.compile(r"application (?:has been |was )?submitted|successfully submitted|submission received|added to .*waitlist", re.I)
                ).first
                await confirmation.wait_for(state="visible", timeout=15_000)
                result.update(status="submitted", submitted=True, submission_confirmed=True)
            else:
                try:
                    await adapter.submit_application()
                except FinalSubmissionForbidden:
                    pass
                result["status"] = "review_reached"
            result.update(
                reached_review=True,
                child_profile_action=adapter.child_profile_action,
                target={
                    "external_location_id": target.location_id,
                    "external_program_id": target.program_id,
                    "centre_name": target.centre_name,
                    "program_name": target.program_name,
                },
            )
            await context.close()
            await browser.close()
    except Exception as error:  # Return a safe type-only failure; never serialize values/page content.
        if result["submission_attempted"]:
            result["status"] = "submission_uncertain"
        result["error_type"] = type(error).__name__
        result["error_stage"] = stage
        result["error_detail"] = adapter.safe_stage if adapter else None
        result["error_controls"] = adapter.safe_diagnostic if adapter else None
        frame = traceback.extract_tb(error.__traceback__)[-1]
        result["error_location"] = {
            "file": os.path.basename(frame.filename),
            "line": frame.lineno,
            "function": frame.name,
        }
        if request.get("debug_screenshot") and page:
            try:
                await page.screenshot(path=request["debug_screenshot"], full_page=False)
            except Exception:
                result["debug_screenshot_failed"] = True
    result["mapping_changes"] = resolver.changes
    return result


def main() -> None:
    request = json.loads(sys.stdin.read())
    print(json.dumps(asyncio.run(run(request)), separators=(",", ":")))


if __name__ == "__main__":
    main()

