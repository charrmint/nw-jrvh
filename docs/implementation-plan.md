# OneKare MVP implementation plan

This plan implements [the MVP architecture](mvp-architecture.md). The supported automatic paths are YWCA public form, YMCA authenticated portal and Parkcrest email-only waitlist request. Other daycares keep verified external links and parent-managed status tracking. The parent completes one [general application](mvp-upfront-questions.md) per child before choosing a daycare.

## Current baseline

The repo already has Rails parent authentication, child profiles, the central general application, BC daycare importing/search and Settings for encrypted YMCA credentials. Browser automation, connected parent email, per-daycare application records, Databricks mapping and automatic submission are proposed work. No separate parent review or approval screen is planned. The parent's **Apply automatically** click starts one attempt for one selected child/daycare target.

## Backend modules and contracts

| Component | Proposed classes / responsibility |
| --- | --- |
| General application | Existing `Child`, `GeneralApplication`, `User`; `GeneralApplications::Normalizer` produces a typed, versioned, provider-neutral snapshot from the selected child and general application. No credentials or provider defaults enter normalization. |
| Directory | Existing `Daycare` and `BcDaycareImporter`; provider configuration identifies workflow, URL or recipient, platform key, centre identifiers, allowed default policy and current mapping version. Imported discovery fields do not overwrite integration configuration. |
| Per-daycare application | `CareApplication` records owner, child, daycare/program, channel, current execution state, current outcome/source, the normalized answer snapshot, Apply automatically request ID, live form observation, mapping snapshot, sent content and operation ID. `ApplicationEvent` records an append-only history. |
| Dispatch | `Applications::CreateAndDispatch` checks ownership, completeness, eligibility, connection availability and duplicate active attempts, then persists the parent's apply action and enqueues work. `Workflow::Coordinator` owns claims, retries, handoffs and state transitions. `Workflow::ResultRecorder` deduplicates worker results and records evidence. |
| Live browser inspection | `Automation::FormInspector` reads current visible labels, required flags, input types, dropdown options, step and conditional questions in the parent's browser session. `Automation::FieldInventory` creates a stable fingerprint from those semantics; live element references remain in that run only. |
| Change comparison | `Integrations::FormComparator` compares the current inventory with the saved current inventory and retains historical inventories/mappings for audit. Historical selectors are never used to fill a new form. |
| AI mapping | `Integrations::MappingSuggester` calls the configured Databricks model **only when the inventory differs** or no mapping exists. It receives the current field inventory, normalized field catalog, previous inventory/diff and allowed default policy, but no parent answers or credentials. It returns mapping rules and dropdown defaults from current options. `Integrations::MappingStore` versions the current configuration and saves history. |
| Browser filling | Shared Python/Playwright engine plus platform adapters use the **current** mapping against **newly observed** controls. If later steps expose new or changed fields, compare and remap again. The same run submits automatically after preparation, except when parent verification/CAPTCHA requires a handoff. If filling cannot complete, stop before submission. |
| Parkcrest email | `Email::WaitlistComposer` renders the configured template from normalized answers. `Email::SendRequest` sends through the parent's connected mailbox after the Apply automatically action. No browser inspection or Databricks call is needed. A successful send sets `waitlist_request_sent`, not `waitlisted`. |
| Parent connections | Existing `ProviderConnection` stores encrypted YMCA credentials. A future `MailboxConnection` holds the parent's send authorization for Parkcrest. Credentials are write-only in the UI and never sent to Databricks. |

## Automatic browser application flow

1. Parent selects a child on the daycare page and clicks **Apply automatically**. Rails creates or reuses one active child/daycare application and records a unique apply request.
2. Normalize the saved child and general application into an immutable run snapshot. Start an isolated browser session. Sign in for YMCA and hand off CAPTCHA or verification when required.
3. Inspect the live provider form. Compare its current field inventory and choices with the saved current inventory.
4. When unchanged, apply the current configuration mapping to live controls. When changed or missing, call Databricks, update and version the configuration mapping, then apply it to the live controls. Historical mappings are comparison records, not fallback fill plans.
5. Fill the form using normalized answers and the configured defaults for unmapped provider-specific priority/marketing-SMS choices. A default must be one of the options observed in this run. Eligibility claims such as catchment come from the parent's general application.
6. Submit in the same run without a separate review or approval action. Record observed confirmation, failure or uncertainty. Do not retry automatically after a possibly successful external submission.

The form may be multi-step. Discovery, comparison and mapping repeat for a newly revealed step or conditional question. The saved fingerprint covers field identity, labels, type, required state and allowed choices rather than ephemeral CSS selectors. The next application always discovers the form again, even when the inventory is unchanged.

## Frontend and route contracts

| Page / action | Responsibility |
| --- | --- |
| General application | Existing `/general_applications` screens collect provider-neutral answers per child. Child identity stays in `/children`. |
| Settings | Existing `/settings` screen stores YMCA portal credentials. Add connected-mailbox status and authorization for Parkcrest. |
| Daycare detail | Show **Apply automatically** only for enabled supported configurations. The action selects a child with a complete general application and posts to the application-creation/dispatch endpoint. Disable repeated clicks while the attempt is active. |
| Application detail/dashboard | Show preparing, parent verification needed, submitted, waitlist request sent, failed or uncertain states, plus later parent-reported waitlist/offer/enrollment outcomes. There is no review or approval page. |
| Verification handoff | Give the parent short-lived access to the same isolated browser session for CAPTCHA/MFA, then resume the worker. This is verification, not an application approval step. |
| External application | For unsupported daycares, open only a verified application URL and let parents report subsequent status. Opening a link is not submission. |

## Data and state invariants

- Every per-daycare application belongs to one parent and one owned child. Separate children applying to the same daycare have separate applications and statuses.
- An Apply automatically request and database execution claim prevent duplicate dispatch from repeat clicks or job retries. External services may still return uncertain outcomes; do not claim exactly-once remote submission.
- Keep execution state distinct from reported outcome. A successful Parkcrest send is **Waitlist request sent**, not confirmed waitlist membership.
- Store the normalized answer snapshot, live form inventory/fingerprint, mapping version used and exact sent content for each run. Later profile or mapping edits never rewrite that history.
- Only the current configuration mapping can be reused, and only after fresh inspection shows the field inventory is unchanged. Changed or missing fields require a new Databricks mapping. Never fill from historical selectors.
- Provider credentials and mailbox tokens never enter AI prompts, application snapshots, routine logs or parent-facing responses.
- A parent-reported status change never triggers a browser or email submission.

## Delivery sequence

| Step | Backend deliverable | UI dependency / completion signal |
| --- | --- | --- |
| 1 | Versioned normalization contract from existing child and general application | No new UI; fictional snapshot shows stable types and field IDs. |
| 2 | Per-daycare application/events tables, ownership checks, apply action and duplicate claim | Daycare detail can select a child and start one attempt. |
| 3 | Parkcrest configured email composer, connected mailbox and send job | Eligible child sends one test-mailbox request; ineligible catchment blocks. |
| 4 | Browser worker with live inspection, field fingerprint and current-form filling | Controlled public-form fixture is discovered on every run. |
| 5 | Databricks mapping suggester and comparison-triggered configuration update | Unchanged fixture uses current mapping; changed field or option triggers a model call and config version change. |
| 6 | YWCA public form and YMCA saved-login adapters with parent verification handoffs | Fictional-data flows submit only to controlled targets; status and evidence remain attributable. |

Use fictional records, owned test forms and a test mailbox while implementing; do not submit to real providers during development checks. The current plan does not include inbox monitoring, reply interpretation, subsequent enrollment paperwork or a universal adapter for unknown providers.
