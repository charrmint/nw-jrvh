# OneKare MVP architecture and implementation plan

This is the proposed design, not an implemented integration. The repository currently contains project documentation. Each provider flow must be validated before enabling production automation.

## Product scope

Use the whiteboard reference for the welcome page, account flow, child selector, current-applications dashboard, daycare search and application wizard.

The MVP includes parent authentication, multiple child profiles, BC-data-backed daycare discovery, saved provider credentials, a connected email account, application preparation, parent review and approval, verification handoffs, external application links, and application tracking that distinguishes verified execution events from parent-reported outcomes.

| Scenario | Workflow | Completion meaning |
| --- | --- | --- |
| YWCA | Public form; fill profile answers; parent handles CAPTCHA when required; review and approve; submit | Record observed submission confirmation, without assuming waitlist membership |
| YMCA | Sign in using securely stored provider credentials; parent handles verification when required; fill; review and approve; submit | Record observed submission confirmation, without assuming waitlist membership |
| Parkcrest Child Care Society, Burnaby | Select child; confirm eligible catchment; generate email; review and approve; send through parent's connected account | **Waitlist request sent**, never automatic waitlist confirmation |

Parkcrest replaces West Vancouver Schools. Exclude inbox monitoring, reply interpretation, registration-link detection, and subsequent enrollment paperwork from the MVP. There is no inbound-email worker or email-to-browser continuation.

## Architecture

Parent UI (Rails + Hotwire) → workflow coordinator → durable job queue → browser or email execution → result back to coordinator → dashboard.

| Component | Owns |
| --- | --- |
| Rails web application | Profiles, search, connected accounts, review screens, approvals, external links, parent status updates and application history |
| Workflow coordinator | Durable state, checkpoints, content-bound approvals, validated status transitions with source attribution, retries and duplicate prevention |
| Shared automation engine | Common execution actions, pausing/resuming, result reporting and confirmation collection |
| Python + Playwright worker | Isolated browser sessions, login, form filling, approved uploads and submission |
| Reusable platform adapters | Platform-specific navigation, field behavior and confirmation detection shared across providers |
| Database-backed provider configuration | Workflow type, platform key, URLs, centre IDs, required questions, validated mappings, templates and supported capabilities |
| Optional custom extensions | Exceptional behavior that configuration and existing adapters cannot express |
| Outbound email worker | Send the approved message using the selected parent's authorized email account; report send outcome |
| Credential and session storage | Encrypted provider credentials, mailbox tokens and browser state; keys managed separately |
| Secure browser handoff | Parent control of the same session for CAPTCHA, MFA or other required verification |
| Databricks model endpoint | Candidate field mappings and optional drafting, with no credentials in prompts |
| Scheduled BC importer | Discovery data and source timestamps; does not overwrite integration configuration |

Initially deploy a Rails web process, Rails background worker and Python browser worker, supported by PostgreSQL/Lakebase, a durable queue, private object storage, managed encryption keys and the browser handoff infrastructure. Outbound email runs in the Rails worker. An email service adapter implements the chosen mailbox provider's send API; supporting additional mailbox services is a separate increment.

## Integration design

Workflow types are `public_form`, `authenticated_portal` and `email_only`. Workflow types describe journeys; platform adapters implement a particular platform's behavior. Do not equate a daycare, a workflow type and an adapter.

Providers may operate multiple centres, and multiple providers may share a platform. Adding a provider on a supported platform should require configuration and validation. Add engineering work only for a new platform or unsupported behavior.

Imported daycares can remain unconfigured and searchable. An application configuration belongs to the relevant program(s), allowing different application methods within one centre. Keep workflow classification separate from automation support (`unconfigured`, `needs_validation`, `enabled`, `paused`); a known workflow type does not mean automation is enabled. External tracking does not require an automation configuration or a fourth automation workflow type.

For enabled integrations, show **Apply with OneKare**. Otherwise show **Apply on provider website** only when the application URL has been verified; fall back to **Visit website** or the known email/phone contact action. Never infer an application URL from the provider's homepage.

Version provider configurations and field mappings. Store the versions used by each run. AI suggestions are unvalidated candidates until reviewed and tested; reuse validated mappings thereafter. Missing or changed required fields pause execution rather than invite guessed answers. Configuration is declarative data, not executable scripts.

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
| Capabilities | Prepare email, parent approval, send email |
| Successful outcome | `waitlist_request_sent`, displayed as **Waitlist request sent** |
| Disabled capabilities | Inbox read, reply interpretation, registration-link detection, enrollment follow-up |

Execution:

1. Select the child and Parkcrest school-age program.
2. Ask the parent to confirm Parkcrest or Aubrey catchment. Record their selection and attestation. Unknown or ineligible answers block sending; no catchment inference or boundary lookup is required for MVP.
3. Validate required profile values and have the parent confirm the local telephone number. Do not invent a specific school-age cutoff absent verified provider requirements.
4. Generate a deterministic message containing the required information and confirmed catchment. AI is unnecessary for this template.
5. Show the sending account, recipient, subject and full body. Require explicit parent approval tied to that exact content and configuration version. Changes invalidate approval.
6. Send through the parent's connected account using an OAuth connection with the narrowest available send permissions. No inbox access is a product requirement.
7. After an explicit successful send response, save the available message/request identifier, timestamp, sender, recipient and approved content snapshot. Display **Waitlist request sent** and explain that membership is not confirmed.

A send acceptance is not proof of delivery, receipt or waitlist membership. No real emails are sent during development or fixture tests.

## State and duplicate handling

Common lifecycle: draft → preparing → needs parent input (when applicable) → ready for review → approved → executing → recorded outcome.

Browser outcomes include submission confirmed, failed and submission uncertain. Parkcrest outcomes include waitlist request sent, send failed and send uncertain. The MVP does not automatically transition Parkcrest to waitlist confirmed.

The coordinator owns transitions. Workers report observations, not inferred business outcomes. Persist run checkpoints, an approval-linked operation identifier and a submission/send attempt before the external action. Lock execution to prevent concurrent sends for the same approved operation; use external idempotency support where available. An operation identifier alone cannot guarantee exactly-once execution across an external service.

If an email request times out after it may have been accepted, mark **Send uncertain** and do not automatically resend. Ask the parent to check their Sent folder and resolve the result. This handles ambiguity without adding inbox monitoring. Likewise, inspect available browser confirmation before retrying a possibly completed form submission.

## Application status tracking

Track what OneKare can verify separately from what the parent reports. Opening a link is not submission; submission or email sending is not proof of waitlist membership. No inbox monitoring or provider decision polling is added to the MVP.

| Application path | Automatically recorded | Parent-reported updates |
| --- | --- | --- |
| YWCA / YMCA through OneKare | Preparation, verification handoff, review readiness, observed submission confirmation or uncertainty | Waitlist confirmation, offer, enrollment, provider rejection or withdrawal |
| Parkcrest email | Preparation, review readiness, **Waitlist request sent**, or send failure/uncertainty | Waitlist confirmation and subsequent provider decisions |
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
- Execution: approval records, run checkpoints, attempts, operation identifiers and confirmation evidence.
- Outbound messages: sender, recipient, approved subject/body, send timestamp and service response identifier; no inbound-message ingestion.

Private object storage holds approved uploads and retained evidence, with access and retention controls. Sensitive content is excluded from routine operational logs.

## Implementation plan

| Milestone | Deliverable | Acceptance |
| --- | --- | --- |
| 1. Foundations | Rails UI shell, parent/child models, provider/centre/platform/configuration models, BC import, external links and tracking dashboard | Imported records remain separate from integration configuration; unconfigured daycares remain searchable; repeated external-link clicks reuse the active tracking entry without marking it submitted |
| 2. Coordinator, review and tracking | Durable queue, snapshots, approvals, run states, operation locks, worker result contract, parent status controls and attributed event history | Unapproved or modified content cannot execute; concurrent jobs cannot start duplicate attempts; parent reports retain their source and never trigger sending; late worker results do not overwrite later outcomes; parents cannot edit another family's records |
| 3. Parkcrest email-only slice | Catchment attestation, required fields, deterministic template, one connected email service and outbound worker | Eligible fixture completes review and mocked send; unknown/ineligible catchment blocks; success is exactly **Waitlist request sent**; ambiguous send never auto-retries |
| 4. Shared browser engine and YWCA | Common browser actions, platform adapter contract, YWCA configuration, secure handoff and confirmation capture | Fixture flow fills mapped values, pauses/resumes for verification and submits only approved answers |
| 5. Saved-login flow and YMCA | Encrypted credential lifecycle, automatic login, session isolation and required platform behavior/configuration | Fixture flow signs in, handles verification, resumes and records outcome without exposing secrets |
| 6. Provider validation and demo | Validate current provider fields, destinations, capabilities and confirmation behavior; exercise recovery and external tracking | Fictional-data demo covers all three workflows plus an external application and parent-reported outcomes without submitting to real providers; link opening and sent email never imply waitlist membership; production capabilities enabled only after provider-specific validation |

Validate provider feasibility early while building foundations; production login, CAPTCHA and submission compatibility are not implied by fixture tests. Use owned forms and a test mailbox for end-to-end sending tests. Calendar estimates remain dependent on team size, hosting choices and mailbox integration.

MVP excludes inbound-email permissions and pipelines, reply classifiers, registration-link extraction, automatic subsequent enrollment, automated catchment geocoding and universal support for unknown application platforms.
