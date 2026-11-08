"""Beyond Care public waitlist adapter with an experiment-only submit guard."""

from __future__ import annotations

from datetime import date
from typing import Any, Protocol

from playwright.async_api import Page


class MappingResolver(Protocol):
    async def resolve(self, *, step: str, inventory: dict[str, Any]) -> dict[str, Any]: ...


class FinalSubmissionForbidden(RuntimeError):
    pass


class VerificationChallenge(RuntimeError):
    pass


class EligibilityBlocked(RuntimeError):
    pass


class BeyondCareWaitlist:
    START_URL = "https://bcchildcentre.ca/wait-list"
    STEP = "waitlist"

    FIELD_SPECS = (
        ("care.preferred_start_date", "#start-date", "date", True),
        ("parent.first_name", "#parent-first", "text", True),
        ("parent.last_name", "#parent-last", "text", True),
        ("child.first_name", "#child-first-1", "text", True),
        ("child.last_name", "#child-last-1", "text", True),
        ("child.date_of_birth", "#child-birth-1", "date", True),
        ("parent.email", "#email", "email", True),
        ("child.extra_needs", "#extra-needs", "textarea", False),
    )

    def __init__(
        self,
        page: Page,
        mapping_resolver: MappingResolver,
        *,
        experiment: bool = True,
        debug_screenshot: str | None = None,
    ):
        self.page = page
        self.mapping_resolver = mapping_resolver
        self.experiment = experiment
        self.debug_screenshot = debug_screenshot
        self.safe_stage = "initialized"
        self.filled_fields: list[str] = []
        self.mapping_reused = False
        self.inventory: dict[str, Any] = {}

    async def open_and_inspect(self) -> dict[str, Any]:
        self.safe_stage = "navigation"
        await self.page.goto(self.START_URL, wait_until="domcontentloaded")
        await self.page.locator("#waitlist-form").wait_for(state="visible")
        await self._guard_verification()
        self.safe_stage = "conditional_children_probe"
        repeatable = await self._probe_additional_child()
        self.safe_stage = "inventory"
        fields = []
        for key, selector, expected_type, expected_required in self.FIELD_SPECS:
            control = self.page.locator(selector)
            if await control.count() != 1 or not await control.is_visible():
                raise RuntimeError(f"Expected live field is missing: {key}")
            live_type = await control.get_attribute("type") or expected_type
            required = await control.get_attribute("required") is not None
            label = await self.page.locator(f'label[for="{selector.removeprefix("#")}"]').inner_text()
            fields.append(
                {
                    "key": key,
                    "label": label.strip(),
                    "type": live_type,
                    "required": required,
                    "provider_name": await control.get_attribute("name"),
                }
            )
            if required != expected_required:
                raise RuntimeError(f"Required state changed for live field: {key}")

        radios = self.page.locator('input[type="radio"][name="program"]')
        choices = []
        for index in range(await radios.count()):
            radio = radios.nth(index)
            radio_id = await radio.get_attribute("id")
            choices.append(
                {
                    "value": await radio.get_attribute("value"),
                    "label": (await self.page.locator(f'label[for="{radio_id}"]').inner_text()).strip(),
                }
            )
        if not choices:
            raise RuntimeError("The live age-category choices are missing")
        fields.insert(
            1,
            {
                "key": "child.age_category",
                "label": "Age Category *",
                "type": "radio",
                "required": True,
                "provider_name": "program",
                "choices": [choice["value"] for choice in choices],
                "choice_labels": {choice["value"]: choice["label"] for choice in choices},
            },
        )
        fields.append(repeatable)
        honeypot = self.page.locator('input[name="website"]')
        self.inventory = {
            "schema_version": 3,
            "step": self.STEP,
            "fields": fields,
            "ignored_hidden_controls": [
                {
                    "provider_name": "website",
                    "type": await honeypot.get_attribute("type"),
                    "purpose": "honeypot",
                }
            ] if await honeypot.count() == 1 else [],
        }
        mapping_count = len(self.mapping_resolver.changes)
        resolved = await self.mapping_resolver.resolve(step=self.STEP, inventory=self.inventory)
        self.mapping_reused = len(self.mapping_resolver.changes) == mapping_count
        return resolved

    async def fill(self, snapshot: dict[str, Any], resolved: dict[str, Any]) -> None:
        self.safe_stage = "mapping_validation"
        live_keys = {field["key"] for field in self.inventory["fields"]}
        catalog = set(snapshot)
        mapping = resolved.get("mapping", {})
        for live_key, canonical_key in mapping.items():
            if live_key not in live_keys or canonical_key not in catalog:
                raise RuntimeError(f"Mapping no longer matches the live form: {live_key}")

        required_mapping_keys = {
            "care.preferred_start_date",
            "child.age_category",
            "parent.first_name",
            "parent.last_name",
            "child.first_name",
            "child.last_name",
            "child.date_of_birth",
            "parent.email",
        }
        missing = sorted(required_mapping_keys - set(mapping))
        if missing:
            raise RuntimeError(f"Required live fields are unmapped: {', '.join(missing)}")

        selectors = {key: selector for key, selector, _kind, _required in self.FIELD_SPECS}
        self.safe_stage = "fill_values"
        for live_key in (
            "care.preferred_start_date",
            "parent.first_name",
            "parent.last_name",
            "child.first_name",
            "child.last_name",
            "child.date_of_birth",
            "parent.email",
        ):
            canonical_key = mapping[live_key]
            await self.page.locator(selectors[live_key]).fill(str(snapshot[canonical_key]))
            self.filled_fields.append(live_key)

        if mapping.get("child.extra_needs") == "child.support_required":
            extra_needs = "" if not snapshot["child.support_required"] else (
                "Support needs indicated in the OneKare application; details require parent follow-up."
            )
            await self.page.locator(selectors["child.extra_needs"]).fill(extra_needs)
            self.filled_fields.append("child.extra_needs")

        self.safe_stage = "age_category"
        category = self.age_category(
            birth_date=snapshot["child.date_of_birth"],
            requested_start_date=snapshot["care.preferred_start_date"],
        )
        observed_choices = next(
            field["choices"] for field in self.inventory["fields"] if field["key"] == "child.age_category"
        )
        if category not in observed_choices:
            raise RuntimeError("Derived age category is not present in the current live choices")
        radio = self.page.locator(f'input[type="radio"][name="program"][value="{category}"]')
        radio_id = await radio.get_attribute("id")
        if not radio_id:
            raise RuntimeError("The derived age category has no live label target")
        await self.page.locator(f'label[for="{radio_id}"]').click()
        if not await radio.is_checked():
            raise RuntimeError("The live age category did not remain selected")
        self.filled_fields.append("child.age_category")

    async def persistence_probe(self) -> dict[str, Any]:
        self.safe_stage = "persistence_probe"
        storage = await self.page.evaluate(
            "() => ({local: Object.keys(localStorage), session: Object.keys(sessionStorage)})"
        )
        form_valid = await self.page.locator("#waitlist-form").evaluate("form => form.checkValidity()")
        fresh_page = await self.page.context.new_page()
        try:
            await fresh_page.goto(self.START_URL, wait_until="domcontentloaded")
            prefilled = await fresh_page.locator(
                "#start-date, #parent-first, #parent-last, #child-first-1, #child-last-1, #child-birth-1, #email, #extra-needs"
            ).evaluate_all("elements => elements.some(element => Boolean(element.value))")
        finally:
            await fresh_page.close()
        return {
            "browser_storage_keys": storage,
            "fresh_page_prefilled": prefilled,
            "form_valid": form_valid,
        }

    async def submit_application(self) -> None:
        if self.experiment:
            raise FinalSubmissionForbidden("Beyond Care final submission is disabled during experiments")
        await self.page.get_by_role("button", name="Submit", exact=True).click()

    async def _guard_verification(self) -> None:
        challenge = self.page.locator(
            'iframe[src*="captcha" i], iframe[src*="challenge" i], .g-recaptcha, .cf-turnstile, [data-sitekey]'
        )
        for index in range(await challenge.count()):
            if await challenge.nth(index).is_visible():
                raise VerificationChallenge("A CAPTCHA or verification challenge is visible")

    async def _probe_additional_child(self) -> dict[str, Any]:
        add_button = self.page.locator("#add-child-button")
        entries = self.page.locator("#children-list .child-entry")
        initial_count = await entries.count()
        await add_button.click()
        await entries.nth(initial_count).wait_for(state="visible")
        conditional_count = await entries.count()
        new_entry = entries.last
        conditional_fields = []
        for data_field in ("first", "last", "birth"):
            control = new_entry.locator(f'[data-child-field="{data_field}"]')
            conditional_fields.append(
                {
                    "provider_name": await control.get_attribute("name"),
                    "type": await control.get_attribute("type"),
                    "required": await control.get_attribute("required") is not None,
                }
            )
        await new_entry.locator(".remove-child-button").click()
        if await entries.count() != initial_count:
            raise RuntimeError("Could not restore the single-child form after conditional discovery")
        return {
            "key": "children.additional",
            "label": (await add_button.inner_text()).strip(),
            "type": "repeatable_group",
            "required": False,
            "trigger": "Add child",
            "observed_count_after_trigger": conditional_count,
            "child_fields": conditional_fields,
        }

    @staticmethod
    def age_category(*, birth_date: str, requested_start_date: str) -> str:
        born = date.fromisoformat(birth_date)
        starts = date.fromisoformat(requested_start_date)
        months = (starts.year - born.year) * 12 + starts.month - born.month
        if starts.day < born.day:
            months -= 1
        if 18 <= months < 36:
            return "toddler"
        if 36 <= months < 72:
            return "preschool"
        raise EligibilityBlocked("Child is outside the observed 18-month-to-5-year age categories at requested start")
