# OneKare MVP architecture and implementation plan

This is the proposed integration design, not an implemented automation. The repository already has parent authentication, child profiles, the central general application, daycare search/importing and credential settings. Per-daycare applications and submission workflows still need implementation. Each provider flow must be validated before enabling production automation. See the [frontend/backend implementation plan](implementation-plan.md) for named classes, shared contracts and assignable tasks.

## Product scope

Use the whiteboard reference for the welcome page, account flow, child selector, current-applications dashboard, daycare search and central general application.

The MVP includes parent authentication, multiple child profiles, a central general application per child, BC-data-backed daycare discovery, saved provider credentials, a connected email account, automatic submission after the parent clicks **Apply automatically**, verification handoffs, external application links, and application tracking that distinguishes verified execution events from parent-reported outcomes. There is no separate parent review or approval screen.

| Scenario | Workflow | Completion meaning |
| --- | --- | --- |
| YWCA | Parent clicks Apply automatically; inspect current public form, map/fill and submit; parent handles CAPTCHA when required | Record observed submission confirmation, without assuming waitlist membership |
| YMCA | Parent clicks Apply automatically; sign in using securely stored provider credentials, inspect current portal form, map/fill and submit; parent handles verification when required | Record observed submission confirmation, without assuming waitlist membership |
| Parkcrest Child Care Society, Burnaby | Parent clicks Apply automatically for an eligible child; generate and send email through the parent's connected account | **Waitlist request sent**, never automatic waitlist confirmation |

Parkcrest replaces West Vancouver Schools. Exclude inbox monitoring, reply interpretation, registration-link detection, and subsequent enrollment paperwork from the MVP. There is no inbound-email worker or email-to-browser continuation.

## Architecture

Parent UI (Rails + Hotwire) → workflow coordinator → durable job queue → browser or email execution → result back to coordinator → dashboard.

| Component | Owns |
| --- | --- |
| Rails web application | Profiles, search, connected accounts, automatic-apply action, external links, parent status updates and application history |
| Workflow coordinator | Durable state, checkpoints, authorized apply actions, validated status transitions with source attribution, retries and duplicate prevention |
| Shared automation engine | Common execution actions, pausing/resuming, result reporting and confirmation collection |
| Python + Playwright worker | Isolated browser sessions, login, live form inspection, form filling and submission |
| Reusable platform adapters | Platform-specific navigation, field behavior and confirmation detection shared across providers |
| Database-backed provider configuration | Workflow type, platform key, URLs, centre IDs, allowed default policies, templates and supported capabilities; historical form observations and mappings are comparison records |
| Optional custom extensions | Exceptional behavior that configuration and existing adapters cannot express |
| Outbound email worker | Send the configured waitlist request using the selected parent's connected email account; report send outcome |
| Credential and session storage | Encrypted provider credentials, mailbox tokens and browser state; keys managed separately |
| Secure browser handoff | Parent control of the same session for CAPTCHA, MFA or other required verification |
| Databricks model endpoint | Candidate field mappings and optional drafting, with no credentials in prompts |
| Scheduled BC importer | Discovery data and source timestamps; does not overwrite integration configuration |

Initially deploy a Rails web process, Rails background worker and Python browser worker, supported by PostgreSQL/Lakebase, a durable queue, private object storage, managed encryption keys and the browser handoff infrastructure. Outbound email runs in the Rails worker. An email service adapter implements the chosen mailbox provider's send API; supporting additional mailbox services is a separate increment.

## Integration design

Workflow types are `public_form`, `authenticated_portal` and `email_only`. Workflow types describe journeys; platform adapters implement a particular platform's behavior. Do not equate a daycare, a workflow type and an adapter.

Providers may operate multiple centres, and multiple providers may share a platform. Adding a provider on a supported platform should require configuration and validation. Add engineering work only for a new platform or unsupported behavior.

Imported daycares can remain unconfigured and searchable. An application configuration belongs to the relevant program(s), allowing different application methods within one centre. Keep workflow classification separate from automation support (`unconfigured`, `needs_validation`, `enabled`, `paused`); a known workflow type does not mean automation is enabled. External tracking does not require an automation configuration or a fourth automation workflow type.

For enabled integrations, show **Apply automatically**. That click authorizes one application attempt for the selected child and daycare. Otherwise show **Apply on provider website** only when the application URL has been verified; fall back to **Visit website** or the known email/phone contact action. Never infer an application URL from the provider's homepage.

For every browser application, inspect the provider's live form and dropdown options in that run's browser session. Compare the freshly observed field inventory with the saved inventory. If unchanged, use the current configuration mapping against the live controls. If changed, send the new inventory and normalized field catalog to Databricks, replace the configuration mapping with its new proposal and use that mapping against the live controls. Keep older inventories and mappings for change comparison and audit, never as the current field inventory or selectors. After filling, submit automatically under the parent's Apply automatically action. Configuration is declarative data, not executable scripts.

### Live form discovery and mapping

1. The parent selects a child on a daycare page and clicks **Apply automatically**. The coordinator records that action and claims one attempt for that child/daycare target.
2. The worker opens the provider form, signs in when required and pauses for parent verification if needed. In that session it reads the current form controls: labels, types, required flags, available choices, step and visible conditional questions.
3. Compare the new field inventory with the current saved inventory. If they match, keep the current configuration mapping. If they differ, send the new inventory and normalized field catalog to Databricks. The model proposes an updated mapping and defaults drawn from the current choices; save it as the new configuration version. Do not send credentials or the parent's answer values to the model.
4. Normalize the selected child's general application and fill the currently observed controls using the active configuration mapping. Provider-specific priority and marketing-SMS questions may use the agreed No defaults. Catchment and other eligibility claims come from the parent-provided general application. If a later step reveals changed or new questions, repeat discovery, comparison and mapping for that step.
5. Submit automatically in the same run, then record observed confirmation or uncertainty. Save the field inventory and mapping used for later comparison. If the form cannot be filled, stop before submitting and report the failure; do not fall back to a historical mapping.

This discovers the form on every browser application and calls Databricks only when the discovered fields or choices differ from the saved inventory, including newly revealed conditional questions. Parkcrest remains a configured email template with no browser form to inspect.

Credentials belong to the parent and the appropriate platform account/login domain. Configuration references connections without containing secrets. Encrypt credentials and session state, isolate browser sessions by parent, exclude secrets from logs/traces/AI prompts, and support replacement and deletion. OneKare's own login passwords are hashed, not stored as recoverable provider credentials.

## Parkcrest configuration and workflow

Source: [Parkcrest's official FAQ](https://www.parkcrestchildcaresociety.ca/about/faq/), checked November 7, 2026. It limits the school-age waitlist to Parkcrest or Aubrey school catchments and requests the child's full name, date of birth, parent/guardian name and local telephone number by email. The page lists `info@parkcrestchildcaresociety.ca` as its contact address.

Represent Parkcrest through generic email-only configuration:

| Setting | Value |
| --- | --- |
| Workflow | `email_only` |
| Program | School-age care |
| Recipient | `info@parkcrestchildcaresociety.ca` |
| Eligibility | Parent confirms Parkcrest or Aubrey school catchment |
| Required profile fields | Child full name, date of birth, parent/guardian name, local telephone number |
| Message | Versioned deterministic subject/body template populated from validated profile data |
| Capabilities | Compose and send email after Apply automatically |
| Successful outcome | `waitlist_request_sent`, displayed as **Waitlist request sent** |
| Disabled capabilities | Inbox read, reply interpretation, registration-link detection, enrollment follow-up |

Execution:

1. Select the child and Parkcrest school-age program.
2. Read the general application's parent-selected Parkcrest or Aubrey catchment. Unknown or ineligible answers block sending; no catchment inference or boundary lookup is required for MVP.
3. Validate the child's name and date of birth, parent/guardian name and local telephone number. Do not invent a specific school-age cutoff absent verified provider requirements.
4. Generate a deterministic message containing the required information. AI is unnecessary for this template.
5. The Apply automatically click authorizes sending this configured request. Send through the parent's connected account using an OAuth connection with the narrowest available send permissions. No inbox access is a product requirement.
6. After an explicit successful send response, save the available message/request identifier, timestamp, sender, recipient and sent content snapshot. Display **Waitlist request sent** and explain that membership is not confirmed.

A send acceptance is not proof of delivery, receipt or waitlist membership. No real emails are sent during development or fixture tests.

## State and duplicate handling

Common lifecycle: draft → preparing → needs parent verification (when applicable) → executing → recorded outcome. A parent's Apply automatically click starts the attempt; there is no separate review or approval transition.

Browser outcomes include submission confirmed, failed and submission uncertain. Parkcrest outcomes include waitlist request sent, send failed and send uncertain. The MVP does not automatically transition Parkcrest to waitlist confirmed.

The coordinator owns transitions. Workers report observations, not inferred business outcomes. Persist the parent-triggered action, run checkpoints, operation identifier and submission/send attempt before the external action. Lock execution to prevent concurrent sends for the same application target; use external idempotency support where available. An operation identifier alone cannot guarantee exactly-once execution across an external service.

If an email request times out after it may have been accepted, mark **Send uncertain** and do not automatically resend. Ask the parent to check their Sent folder and resolve the result. This handles ambiguity without adding inbox monitoring. Likewise, inspect available browser confirmation before retrying a possibly completed form submission.

## Application status tracking

Track what OneKare can verify separately from what the parent reports. Opening a link is not submission; submission or email sending is not proof of waitlist membership. No inbox monitoring or provider decision polling is added to the MVP.

| Application path | Automatically recorded | Parent-reported updates |
| --- | --- | --- |
| YWCA / YMCA through OneKare | Preparation, verification handoff, observed submission confirmation or uncertainty | Waitlist confirmation, offer, enrollment, provider rejection or withdrawal |
| Parkcrest email | Preparation, **Waitlist request sent**, or send failure/uncertainty | Waitlist confirmation and subsequent provider decisions |
| External website or contact method | Saved tracking entry and application-link opening when applicable | Whether the application was submitted, followed by waitlist and subsequent outcomes |

External application flow:

1. Select the child and daycare/program. When opening an external application link, create or reuse its active tracking entry and record a link-opened event. Repeated clicks do not create duplicate applications.
2. On return to the dashboard, offer **Have you submitted your application?** with **Mark as submitted** and **Not yet**. This prompt does not depend on detecting activity on the external website.
3. Marking submitted records a parent-sourced update. Not yet leaves the entry at saved/not submitted. A website visit alone never advances submission status.
4. Let the parent later select **Waitlisted**, **Offer received**, **Enrolled**, **Declined**, or **Withdrawn**, with an optional note/reference. Clarify whether Declined means the provider rejected the application or the parent declined an offer.

Maintain execution state separately from the application's reported outcome. A parent reporting Waitlisted must not rewrite an uncertain automation attempt as successfully submitted. Likewise, a delayed worker result must not regress an application from a later parent-reported outcome. Parent status edits never dispatch a new submission or email.

Display attribution next to the current status and in its history, for example:

- **Submitted · Confirmed by OneKare** — backed by observed submission evidence.
- **Applied · Reported by you** — a parent reports submission outside OneKare or resolves uncertainty manually.
- **Waitlisted · Reported by you** — parent reports confirmation from the provider.
- **Waitlist request sent · Email sent [date]** — backed by the outbound service's successful send response, not a membership confirmation.

Every status change records its previous/new value, timestamp, source (`automation` or `parent`), actor or run identifier, and optional note/evidence reference. Keep the current outcome for dashboard queries plus an append-only history; corrections create a new event rather than erasing previous reports. Link openings are activity events, not successful application status changes. Parents can update only their own family's applications.

## Data model

- Discovery: providers, centres, care programs, imported facility identifiers and vacancy source timestamps.
- Integration: platforms, versioned provider configurations, mappings and validation records.
- Family: parent accounts, child profiles and reusable contact information.
- Connections: encrypted provider credentials, isolated sessions and mailbox authorization tokens.
- Applications: child, daycare/program, submission channel (OneKare browser, OneKare email or external), eligibility attestation where applicable, answer/message snapshot, configuration version when automated, execution state and current reported outcome with source. External entries may have no configuration or known program yet.
- Application history: status changes and activity events with timestamps, previous/new values where applicable, source, parent actor or automation run, and optional notes/evidence references. Store link-opened activity separately from submission confirmation.
- Execution: parent-triggered apply actions, run checkpoints, attempts, operation identifiers and confirmation evidence.
- Outbound messages: sender, recipient, sent subject/body, send timestamp and service response identifier; no inbound-message ingestion.

Private object storage holds any required uploads and retained evidence, with access and retention controls. Sensitive content is excluded from routine operational logs.

## Implementation plan

| Milestone | Deliverable | Acceptance |
| --- | --- | --- |
| 1. Foundations | Rails UI shell, parent/child models, provider/centre/platform/configuration models, BC import, external links and tracking dashboard | Imported records remain separate from integration configuration; unconfigured daycares remain searchable; repeated external-link clicks reuse the active tracking entry without marking it submitted |
| 2. Coordinator and tracking | Durable queue, normalized snapshots, run states, operation locks, worker result contract, parent status controls and attributed event history | One Apply automatically action creates one attempt; concurrent jobs cannot start duplicate attempts; parent reports retain their source and never trigger sending; late worker results do not overwrite later outcomes; parents cannot edit another family's records |
| 3. Parkcrest email-only slice | Catchment eligibility from the general application, required fields, deterministic template, one connected email service and outbound worker | Eligible fixture sends a mocked email after Apply automatically; unknown/ineligible catchment blocks; success is exactly **Waitlist request sent**; ambiguous send never auto-retries |
| 4. Shared browser engine and YWCA | Common browser actions, live field discovery/comparison, conditional Databricks remapping, platform adapter contract, secure handoff and confirmation capture | Fixture flow reuses the current mapping when live fields match, remaps when they differ, pauses/resumes for verification and submits after Apply automatically |
| 5. Saved-login flow and YMCA | Encrypted credential lifecycle, automatic login, session isolation and required platform behavior/configuration | Fixture flow signs in, handles verification, resumes and records outcome without exposing secrets |
| 6. Provider validation and demo | Validate current provider fields, destinations, capabilities and confirmation behavior; exercise recovery and external tracking | Fictional-data demo covers all three workflows plus an external application and parent-reported outcomes without submitting to real providers; link opening and sent email never imply waitlist membership; production capabilities enabled only after provider-specific validation |

Validate provider feasibility early while building foundations; production login, CAPTCHA and submission compatibility are not implied by fixture tests. Use owned forms and a test mailbox for end-to-end sending tests. Calendar estimates remain dependent on team size, hosting choices and mailbox integration.

MVP excludes inbound-email permissions and pipelines, reply classifiers, registration-link extraction, automatic subsequent enrollment, automated catchment geocoding and universal support for unknown application platforms.
