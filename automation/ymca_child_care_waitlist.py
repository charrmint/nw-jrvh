"""Deterministic YMCA BC child-care waitlist browser adapter.

The coordinator supplies credentials and a normalized application in memory. This
module never logs either. A mapping resolver receives only semantic field inventory.
Experiment mode always stops at Review and refuses final submission.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import re
from typing import Any, Protocol
from urllib.parse import urlparse

from playwright.async_api import Page, TimeoutError as PlaywrightTimeoutError


class MappingResolver(Protocol):
    async def resolve(self, *, step: str, inventory: dict[str, Any]) -> dict[str, Any]: ...


class FinalSubmissionForbidden(RuntimeError):
    pass


@dataclass(frozen=True)
class Target:
    location_id: str
    program_id: str
    centre_name: str
    program_name: str


class YmcaChildCareWaitlist:
    START_URL = "https://mycommunity.bc.ymca.ca/s/find-child-care"
    LOGIN_URL = (
        "https://mycommunity.bc.ymca.ca/s/login/"
        "?ec=302&startURL=%2Fs%2Ffind-child-care"
    )

    def __init__(
        self,
        page: Page,
        mapping_resolver: MappingResolver,
        *,
        experiment: bool = True,
        allow_child_creation: bool = True,
        debug_screenshot: str | None = None,
    ):
        self.page = page
        self.mapping_resolver = mapping_resolver
        self.experiment = experiment
        self.allow_child_creation = allow_child_creation
        self.debug_screenshot = debug_screenshot
        self.safe_stage = "initialized"
        self.child_profile_action: str | None = None
        self.observed_choices: dict[str, list[str]] = {}
        self.safe_diagnostic: list[dict[str, str | None]] | None = None

    async def login(self, *, username: str, password: str) -> None:
        self.safe_stage = "login_navigation"
        await self.page.goto(self.LOGIN_URL)
        if "/s/login" not in self.page.url:
            return
        self.safe_stage = "login_fields"
        username_field = self.page.get_by_label("Username", exact=False)
        password_field = self.page.get_by_label("Password", exact=False)
        await username_field.press_sequentially(username)
        await password_field.press_sequentially(password)
        await password_field.press("Tab")
        self.safe_stage = "login_button"
        await self.page.get_by_role("button", name="Login", exact=True).click()
        self.safe_stage = "login_redirect"
        await self.page.wait_for_url(re.compile(r"https://mycommunity\.bc\.ymca\.ca/s/(?!login)"))

    async def choose_first_compatible_program(
        self,
        *,
        program_text: str,
        centre_text: str | None = None,
        fallback_location_id: str | None = None,
        fallback_program_id: str | None = None,
    ) -> Target:
        self.safe_stage = "find_child_care_navigation"
        await self.page.goto(self.START_URL)
        self.safe_stage = "find_child_care_heading"
        await self.page.get_by_role("heading", name="Find child care", exact=False).wait_for()
        self.safe_stage = "compatible_centre_button"
        centre_buttons = self.page.locator("button").filter(has_text=program_text)
        if centre_text:
            centre_buttons = centre_buttons.filter(has_text=centre_text)
        await centre_buttons.first.wait_for()
        if await centre_buttons.count() == 0:
            raise RuntimeError(f"No open YMCA centre offers {program_text}")

        first_centre = centre_buttons.first
        centre_name = (await first_centre.inner_text()).split(" OPEN", 1)[0].strip()
        self.safe_stage = "centre_details"
        await first_centre.click()
        program = self.page.get_by_role("heading").filter(has_text=program_text).first
        program_name = (await program.inner_text()).strip()
        card = program.locator("xpath=ancestor::*[.//button[contains(normalize-space(.), 'Join waitlist')]][1]")
        self.safe_stage = "join_waitlist_button"
        join_button = card.get_by_role("button", name="Join waitlist", exact=True)
        await join_button.scroll_into_view_if_needed()
        await join_button.click(force=True)
        self.safe_stage = f"waitlist_step:{urlparse(self.page.url).path}"
        try:
            await self.page.get_by_role(
                "heading", name="Join Child Care Waitlist", exact=True
            ).first.wait_for(timeout=30_000)
        except PlaywrightTimeoutError:
            self.safe_stage = f"waitlist_step_timeout:{self.page.url}"
            if self.debug_screenshot:
                await self.page.screenshot(path=self.debug_screenshot, full_page=False)
            raise

        location_id, program_id = self._target_ids_from_url()
        if fallback_location_id and location_id != fallback_location_id:
            raise RuntimeError("YMCA selected a different location than the configured daycare")
        if fallback_program_id and program_id != fallback_program_id:
            raise RuntimeError("YMCA selected a different program than the configured daycare")
        return Target(location_id, program_id, centre_name, program_name)

    async def fill_child_step(self, snapshot: dict[str, Any]) -> None:
        self.safe_stage = "child_identity"
        await self._select_or_create_child(snapshot)
        await self.page.get_by_label("Does this child live in the Cascade Heights", exact=False).first.wait_for()

        self.safe_stage = "child_catchment"
        catchment = "Yes" if snapshot["school.catchment"] == "cascade_or_inman" else "No"
        await self._choose(
            "Does this child live in the Cascade Heights",
            catchment,
            inventory_key="school.catchment.cascade_or_inman",
        )
        self.safe_stage = "child_support"
        await self._choose(
            "Does this child require any support",
            "Yes" if snapshot["child.support_required"] else "No",
            inventory_key="child.support_required",
        )
        school = snapshot.get("school.name") or "School Age Care Not Required"
        if self._age(snapshot["child.date_of_birth"]) < 5:
            school = "School Age Care Not Required"
        self.safe_stage = "child_school"
        await self._choose_school(school)
        self.safe_stage = "child_start_date"
        await self.page.get_by_label("Preferred start date", exact=False).first.fill(
            self._portal_date(snapshot["care.preferred_start_date"])
        )
        self.safe_stage = "child_schedule"
        await self._choose(
            "Preferred schedule",
            self._schedule(snapshot["care.preferred_schedule"]),
            inventory_key="care.preferred_schedule",
        )
        self.safe_stage = "child_inventory"
        await self._observe("your_child")
        self.safe_stage = "child_next"
        await self.page.get_by_role("button", name="Next", exact=True).click()
        self.safe_stage = "family_transition"
        try:
            await self.page.get_by_label("Second parent or guardian", exact=False).first.wait_for()
        except Exception:
            if self.debug_screenshot:
                await self.page.screenshot(path=self.debug_screenshot, full_page=False)
            raise

    async def _create_child(self, snapshot: dict[str, Any]) -> None:
        self.safe_stage = "child_create_open"
        new_child = self.page.get_by_text("New child", exact=True)
        if not await new_child.is_visible():
            add_child = self.page.get_by_role("button", name="Add a child", exact=True)
            await add_child.click()
            try:
                await new_child.wait_for(timeout=3_000)
            except PlaywrightTimeoutError:
                await add_child.evaluate("element => element.click()")
                await new_child.wait_for()
        self.safe_stage = "child_create_first_name"
        first_name = self.page.get_by_label("First name", exact=False)
        if await first_name.count() == 0:
            self.safe_diagnostic = await self.page.locator("input:visible").evaluate_all(
                """elements => elements.map(element => ({
                  type: element.getAttribute('type'),
                  name: element.getAttribute('name'),
                  aria_label: element.getAttribute('aria-label')
                }))"""
            )
            raise RuntimeError("Visible child first-name input is not label-associated")
        await first_name.fill(snapshot["child.first_name"])
        self.safe_stage = "child_create_last_name"
        await self.page.get_by_label("Last name", exact=False).fill(snapshot["child.last_name"])
        self.safe_stage = "child_create_birthdate"
        await self.page.get_by_label("Birthdate or estimated birthdate", exact=False).fill(
            self._portal_date(snapshot["child.date_of_birth"])
        )
        self.child_profile_action = "created_from_saved_data"

    async def _select_or_create_child(self, snapshot: dict[str, Any]) -> None:
        try:
            expected_name = f'{snapshot["child.first_name"]} {snapshot["child.last_name"]}'
            child_selector = self.page.get_by_role("combobox").filter(
                has=self.page.get_by_text("Select an Option", exact=False)
            ).first
            if await child_selector.count() > 0:
                await child_selector.click()
                existing_option = self.page.get_by_role("option", name=expected_name, exact=True)
                if await existing_option.count() > 0:
                    await existing_option.click()
                    self.child_profile_action = "reused_existing"
                    return
                await self.page.keyboard.press("Escape")

            if await self._selected_child_matches(snapshot):
                self.child_profile_action = "reused_preselected"
                return
            if self.allow_child_creation:
                await self._create_child(snapshot)
                return
            raise RuntimeError("Existing YMCA child was not selectable; refusing to create a duplicate")
        except Exception:
            if self.debug_screenshot:
                await self.page.screenshot(path=self.debug_screenshot, full_page=False)
            raise

    async def fill_family_step(self, snapshot: dict[str, Any]) -> None:
        if snapshot.get("parent.second_guardian_name"):
            raise RuntimeError("Adding a new second guardian is not implemented safely")
        self.safe_stage = "family_second_guardian"
        await self._choose(
            "Second parent or guardian",
            "None",
            inventory_key="parent.second_guardian",
        )
        self.safe_stage = "family_inventory"
        await self._observe("your_family")
        self.safe_stage = "family_next"
        await self.page.get_by_role("button", name="Next", exact=True).click()
        self.safe_stage = "family_guardian_form"
        try:
            await self.page.get_by_label("First name", exact=False).first.wait_for()
        except Exception:
            if self.debug_screenshot:
                await self.page.screenshot(path=self.debug_screenshot, full_page=False)
            raise
        self.safe_stage = "guardian_questions_wait"
        await self._ensure_priority_questions_loaded()

        self.safe_stage = "guardian_inventory"
        await self._observe("your_family_guardian_details")
        values = {
            "First name": snapshot["parent.first_name"],
            "Last name": snapshot["parent.last_name"],
            "Email": snapshot["parent.email"],
            "Birthdate": self._portal_date(snapshot["parent.date_of_birth"]),
            "Mobile phone": snapshot["parent.local_phone"],
            "Mailing street": snapshot["parent.mailing_street"],
            "Mailing city": snapshot["parent.mailing_city"],
            "Mailing province": snapshot["parent.mailing_province"],
            "Mailing postal code": snapshot["parent.mailing_postal_code"],
            "Mailing country": snapshot["parent.mailing_country"],
        }
        for label, value in values.items():
            self.safe_stage = f"guardian_value:{label}"
            await self.page.get_by_label(label, exact=False).first.fill(str(value))

        self.safe_stage = "guardian_sms"
        sms = self.page.get_by_role("checkbox", name="I agree to receive notifications by text message")
        await sms.set_checked(False)
        self.safe_stage = "guardian_priorities"
        for question in await self._priority_comboboxes():
            await question.click()
            await self.page.get_by_role("option", name="No", exact=True).click()
        self.safe_stage = "guardian_next"
        await self.page.get_by_role("button", name="Next", exact=True).click()
        await self.page.get_by_text("Choose the program type that best fits your child", exact=False).wait_for()

    async def _ensure_priority_questions_loaded(self) -> None:
        priority_question = self.page.get_by_text(
            "Are you a benefits eligible YMCA BC employee?", exact=False
        ).first
        for attempt in range(2):
            try:
                await priority_question.wait_for(timeout=10_000)
                return
            except PlaywrightTimeoutError:
                load_error = self.page.get_by_text(
                    "questions for this person could not be loaded", exact=False
                ).first
                if not await load_error.is_visible() or attempt == 1:
                    raise RuntimeError("YMCA guardian priority questions did not load")
                self.safe_stage = "guardian_questions_retry"
                await self.page.get_by_role("button", name="Back", exact=True).click()
                await self.page.get_by_text("Designate up to two parents or guardians", exact=False).wait_for()
                await self.page.get_by_role("button", name="Next", exact=True).click()
                await self.page.get_by_label("First name", exact=False).first.wait_for()

    async def keep_first_location_and_open_review(self) -> None:
        self.safe_stage = "locations_inventory"
        await self._observe("locations")
        self.safe_stage = "locations_selection"
        chosen = self.page.get_by_text("1 centre chosen", exact=False)
        if not await chosen.is_visible():
            if self.debug_screenshot:
                await self.page.screenshot(path=self.debug_screenshot, full_page=False)
            raise RuntimeError("Expected the initiating centre to remain selected")
        self.safe_stage = "locations_next"
        await self.page.get_by_role("button", name="Next", exact=True).click()
        self.safe_stage = "review_heading"
        await self.page.get_by_role("heading", name="Review and submit").wait_for()
        self.safe_stage = "review_inventory"
        await self._observe("review")

    async def submit_application(self) -> None:
        if self.experiment:
            raise FinalSubmissionForbidden("YMCA final submission is disabled during experiments")
        await self.page.get_by_role("button", name="Submit application", exact=True).click()

    async def _observe(self, step: str) -> None:
        if step == "locations":
            inventory = {
                "schema_version": 3,
                "step": step,
                "fields": [
                    {
                        "key": "program_type",
                        "type": "button_group",
                        "required": True,
                        "choices": [
                            "Infant Toddler · Ages 0–3",
                            "3 to 5 Years · Ages 3–5",
                            "Preschool · Ages 3–5",
                            "School Age · Ages 4–13",
                        ],
                    },
                    {
                        "key": "centres",
                        "type": "multi_select_map_list",
                        "required": True,
                        "selected_limit": 5,
                    },
                ],
            }
            await self.mapping_resolver.resolve(step=step, inventory=inventory)
            return

        fields = await self.page.locator(
            "input, select, textarea, [role=combobox], button[aria-haspopup=listbox]"
        ).evaluate_all(
            """elements => elements.filter(e => e.offsetParent !== null).map((e, index) => ({
              key: e.getAttribute('name') || e.getAttribute('aria-label') ||
                (e.labels && e.labels[0] && e.labels[0].innerText.trim()) ||
                (e.closest('label') && e.closest('label').innerText.trim()) || `control-${index}`,
              type: e.getAttribute('role') || e.getAttribute('type') || e.tagName.toLowerCase(),
              required: e.required || e.getAttribute('aria-required') === 'true',
              choices: e.tagName === 'SELECT' ? [...e.options].map(o => o.textContent.trim()) : []
            }))"""
        )
        normalized_fields = [self._normalize_live_field(step, field) for field in fields]
        if step == "your_child":
            for label, key in (
                ("Does this child live in the Cascade Heights", "school.catchment.cascade_or_inman"),
                ("Does this child require any support", "child.support_required"),
                ("Which school does your child", "school.name"),
                ("Preferred schedule", "care.preferred_schedule"),
            ):
                field = await self._live_combobox_field(label, key)
                if field:
                    normalized_fields.append(field)
        elif step == "your_family":
            field = await self._live_combobox_field("Second parent or guardian", "parent.second_guardian")
            if field:
                normalized_fields.append(field)

        inventory = {
            "schema_version": 3,
            "step": step,
            "fields": list({field["key"]: field for field in normalized_fields}.values()),
        }
        await self.mapping_resolver.resolve(step=step, inventory=inventory)

    async def _live_combobox_field(self, label: str, key: str) -> dict[str, Any] | None:
        combobox = self.page.get_by_label(label, exact=False).first
        if await combobox.count() == 0:
            return None
        known_choices = {
            "school.catchment.cascade_or_inman": ["Yes", "No"],
            "child.support_required": ["Yes", "No"],
            "parent.second_guardian": ["None", "Add a new parent or guardian"],
            "care.preferred_schedule": [
                "Any Available Option",
                "Early Years | 2 Days Part Time (T/Th)",
                "Early Years | 3 Days Part Time (M/W/F)",
                "Early Years | 5 Days Full Time",
                "School Age | AM + PM | 2 Days Part Time (T/Th)",
                "School Age | AM + PM | 3 Days Part Time (M/W/F)",
                "School Age | AM + PM | 5 Days Full Time",
                "School Age | AM only | 5 Days Full Time",
                "School Age | PM only | 5 Days Full Time",
            ],
        }
        return {
            "key": key,
            "label": label,
            "type": "combobox",
            "required": await combobox.get_attribute("aria-required") == "true",
            "choices": known_choices.get(key, self.observed_choices.get(key, [])),
        }

    @staticmethod
    def _normalize_live_field(step: str, field: dict[str, Any]) -> dict[str, Any]:
        label = field["key"].strip()
        normalized_label = label.lstrip("*").strip()
        lowered = normalized_label.casefold()
        exact = {
            "first name": "parent.first_name" if "family" in step else "child.first_name",
            "last name": "parent.last_name" if "family" in step else "child.last_name",
            "email": "parent.email",
            "birthdate": "parent.date_of_birth",
            "birthdate or estimated birthdate": "child.birthdate_or_estimated",
            "mobile phone": "parent.mobile_phone",
            "mailing street": "parent.mailing_street",
            "mailing city": "parent.mailing_city",
            "mailing province": "parent.mailing_province",
            "mailing postal code": "parent.mailing_postal_code",
            "mailing country": "parent.mailing_country",
            "second parent or guardian": "parent.second_guardian",
            "preferred start date": "care.preferred_start_date",
            "preferred schedule": "care.preferred_schedule",
        }
        key = exact.get(lowered, normalized_label)
        if "cascade heights or inman" in lowered:
            key = "school.catchment.cascade_or_inman"
        elif "require any support" in lowered:
            key = "child.support_required"
        elif "which school does your child" in lowered:
            key = "school.name"
        elif "receive notifications by text message" in lowered:
            key = "parent.marketing_sms"
        elif lowered.startswith("are you "):
            key = "priority." + re.sub(r"[^a-z0-9]+", "_", lowered).strip("_")

        normalized = {**field, "key": key, "label": label}
        if key.startswith("priority.") or key in {
            "school.catchment.cascade_or_inman",
            "child.support_required",
        }:
            normalized["choices"] = ["Yes", "No"]
        elif key == "parent.second_guardian":
            normalized["choices"] = ["None", "Add a new parent or guardian"]
        elif key == "care.preferred_schedule":
            normalized["choices"] = [
                "Any Available Option",
                "Early Years | 2 Days Part Time (T/Th)",
                "Early Years | 3 Days Part Time (M/W/F)",
                "Early Years | 5 Days Full Time",
                "School Age | AM + PM | 2 Days Part Time (T/Th)",
                "School Age | AM + PM | 3 Days Part Time (M/W/F)",
                "School Age | AM + PM | 5 Days Full Time",
                "School Age | AM only | 5 Days Full Time",
                "School Age | PM only | 5 Days Full Time",
            ]
        return normalized

    async def _selected_child_matches(self, snapshot: dict[str, Any]) -> bool:
        expected_name = f'{snapshot["child.first_name"]} {snapshot["child.last_name"]}'.casefold()
        headings = await self.page.get_by_role("heading", level=3).all_text_contents()
        if expected_name not in [heading.strip().casefold() for heading in headings]:
            return False
        birthdate = self.page.get_by_label("Birthdate or estimated birthdate", exact=False)
        return (await birthdate.input_value()).strip() == self._portal_date(snapshot["child.date_of_birth"])

    async def _choose(self, label: str, option: str, *, inventory_key: str | None = None) -> None:
        combobox = self.page.get_by_label(label, exact=False).first
        choice = self.page.get_by_role("option", name=option, exact=True)
        if await choice.count() == 0 or not await choice.first.is_visible():
            await combobox.click()
        if inventory_key:
            visible_options = self.page.locator("[role=listbox]:visible [role=option]")
            observed = list(
                dict.fromkeys(
                    value.strip()
                    for value in await visible_options.all_text_contents()
                    if value.strip()
                )
            )
            self.observed_choices[inventory_key] = observed or [option]
        await choice.first.click()

    async def _choose_school(self, preferred_school: str) -> None:
        combobox = self.page.get_by_label("Which school does your child", exact=False).first
        await combobox.click()
        preferred = self.page.get_by_role("option", name=preferred_school, exact=True)
        if await preferred.count() > 0:
            selected = preferred.first
        else:
            selected = self.page.get_by_role(
                "option", name="School Age Care Not Required", exact=True
            ).first
        self.observed_choices["school.name"] = [await selected.inner_text()]
        await selected.click()

    async def _priority_comboboxes(self):
        boxes = self.page.get_by_role("combobox")
        return [
            boxes.nth(i)
            for i in range(await boxes.count())
            if "Are you" in (await boxes.nth(i).get_attribute("aria-label") or "")
        ]

    def _target_ids_from_url(self) -> tuple[str, str]:
        from urllib.parse import parse_qs, urlparse

        query = parse_qs(urlparse(self.page.url).query)
        return query["locationId"][0], query["courseId"][0]

    @staticmethod
    def _portal_date(value: str) -> str:
        return date.fromisoformat(value).strftime("%b %-d, %Y")

    @staticmethod
    def _age(value: str) -> int:
        born = date.fromisoformat(value)
        today = date.today()
        return today.year - born.year - ((today.month, today.day) < (born.month, born.day))

    @staticmethod
    def _schedule(value: str) -> str:
        return {
            "any_available": "Any Available Option",
            "full_time": "Early Years | 5 Days Full Time",
            "part_time": "Early Years | 3 Days Part Time (M/W/F)",
            "before_school": "School Age | AM only | 5 Days Full Time",
            "after_school": "School Age | PM only | 5 Days Full Time",
            "before_and_after_school": "School Age | AM + PM | 5 Days Full Time",
        }[value]

