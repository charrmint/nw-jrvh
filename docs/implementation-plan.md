# OneKare frontend and backend implementation plan

## Scope and working agreement

This is the proposed implementation contract, not a list of implemented classes. It implements [the MVP architecture](mvp-architecture.md): YWCA public forms, YMCA saved-credential portal applications, Parkcrest email-only requests, and parent-managed tracking for external applications. No inbox monitoring or automatic enrollment follow-up.

Current baseline: Rails scaffold, PostgreSQL configuration, dotenv and Hotwire initialization. Business models, authenticated pages, provider integrations and a durable workflow runner still need implementation. Verify the frontend initialization is present on the branch before starting UI work.

Use server-rendered Rails ERB, Turbo Frames and Stimulus. Do not create a separate SPA or duplicate the domain model in JavaScript. Frontend contributors own views, styles and browser interactions; backend contributors own controllers, presenters, authorization, models and services. Pair on each feature's route/form contract before implementation.

Use the names below consistently. In particular, the application record is `CareApplication`, not `Application` (which already names the Rails application). Rails HTTP controllers may be `ApplicationsController`. A UI “component” initially means an ERB partial, not a new component framework.

## Team lanes and shared-file ownership

| Lane | Work | Ownership |
| --- | --- | --- |
| Frontend | Shell, forms, discovery, wizard, dashboard and handoff UI | `app/views/`, `app/assets/stylesheets/`, `app/javascript/controllers/` |
| Backend core | Authentication, profiles, directory, application state, approval and tracking | Models, controllers, presenters, policies, core services and jobs |
| Integrations | BC import, email transport, browser engine, platform adapters and configuration validation | Integration services, `automation/`, provider fixtures and worker contracts |
| Integration owner (one rotating person) | Merge sequencing, shared schema/routes/contracts, end-to-end checks | `config/routes.rb`, `db/schema.rb`, shared fixtures, contract changes |

These are lanes, not a required team size. With two people, combine backend core and integrations. With more people, split frontend into discovery/profile and application/connection work. Assign one owner to each ticket and a counterpart reviewer. Do not have multiple teammates independently generate authentication, modify the same layout, or define competing application-status enums.

Migrations belong to the feature's backend owner. Merge schema changes before consumers and regenerate the schema from migrations rather than resolving it by guessing. Each paired ticket merges with fixtures and a documented route/form contract; frontend can work with fictional seed records before a real integration exists.

## 1. Modules and proposed classes

### Identity and profiles

| Class | Responsibility |
| --- | --- |
| `User`, `Session`, `Current` | Parent identity, session ownership and request-local authenticated user |
| `ChildProfile` | Child name/date of birth; belongs to `User` |
| `RegistrationsController`, `SessionsController`, `PasswordsController` | Sign up, login/logout and password reset; follow Rails authentication conventions |
| `ProfilesController`, `ChildrenController` | Parent contact information and owned child profiles |
| `Authentication` controller concern | Require login; establish current user; public landing/auth routes opt out |
| `CareApplicationPolicy`, `ConnectionPolicy` | Ownership and permitted actions; plain Ruby policy objects unless a policy library is deliberately adopted |

Use one authentication scaffold, enable password hashing, and extend it for signup. Parent contact fields live on `User` for MVP; do not introduce a household/multi-guardian permission system yet. Always scope child/application lookups through `Current.user`, including nested endpoints.

### Directory and integration configuration

| Class | Responsibility |
| --- | --- |
| `Provider`, `Centre`, `CareProgram` | Operating organization, physical location and offered care program |
| `IntegrationPlatform` | Stable adapter key and allowed login/application origins |
| `ProviderConfiguration`, `ProviderConfigurationVersion` | Stable integration identity plus immutable validated versions of declarative settings |
| `ProgramIntegration` | Links a care program to its active provider configuration; multiple programs may share a configuration |
| `Directory::Search` | Validated search, pagination, location and program/vacancy filters |
| `Directory::CentrePresenter` | Display-ready listing, source dates and supported/external action labels |
| `Imports::BcChildcareImporter`, `ImportBcChildcareJob`, `ImportRun` | Fetch/validate/normalize/upsert BC records and retain import results |
| `Integrations::ConfigurationValidator` | Validate workflow type, adapter compatibility, question schema, recipient/origins and capabilities |
| `Integrations::MappingSuggester` | Optional Databricks mapping suggestions; never directly enables a configuration |

Use configuration tasks/seeds for onboarding the initial providers; an admin UI is not required. YWCA/YMCA platform names must follow inspection of the actual platforms. Do not invent or hard-code an adapter class per daycare.

### Applications, review and tracking

| Class | Responsibility |
| --- | --- |
| `CareApplication` | Owned child/centre/program application, selected channel and current state |
| `ApplicationRevision` | Immutable answers/eligibility/rendered message snapshot and content digest |
| `Approval` | User approval of an exact revision, configuration version and sending identity |
| `ApplicationEvent` | Append-only state/activity history with attribution |
| `Applications::Create` | Create/reuse active tracking entries and validate child/program ownership |
| `Applications::Revise` | Validate input, create a new revision and invalidate any stale approval |
| `Applications::ReviewPresenter` | Exact answers or outbound message plus missing information and allowed actions |
| `Applications::StatusPresenter` | Consistent labels, source attribution and next actions for all screens |
| `Applications::RecordParentOutcome` | Record manual outcomes/corrections without triggering execution |
| `Workflow::Coordinator` | Authoritative transition/approval/dispatch/resume/result logic |
| `Workflow::ResultRecorder` | Deduplicate worker results, record evidence, update execution state and append events atomically |
| `PrepareApplicationJob`, `ExecuteApplicationJob` | Run preparation or approved execution asynchronously through the coordinator |
| `ExecutionAttempt`, `SubmissionEvidence` | Attempt identity, checkpoints, result and private confirmation evidence |

Controllers are thin and call services. Workers cannot mutate business status directly. `CareApplication` is a record, not a container for every workflow implementation.

### Connections and email

| Class | Responsibility |
| --- | --- |
| `ProviderConnection` | User/platform/login-origin association and encrypted username/password |
| `MailboxConnection` | User/mail service/sender association and encrypted OAuth tokens |
| `Connections::CredentialStore` | Authorized encrypt/decrypt/update/delete operations; secrets excluded from read presenters |
| `Connections::MailboxAuthorization` | OAuth state validation, callback exchange, token refresh and disconnect |
| `Email::WaitlistComposer` | Render deterministic configured template from an application revision |
| `Email::SendApprovedMessage` | Verify current approval, claim attempt and invoke mail transport exactly once per accepted dispatch |
| `Email::Transport` | Interface: `send_message(message, connection, operation_id)` returns accepted, rejected or uncertain |
| `Email::TestTransport` | Controlled fake success/failure/timeout for tests and demos |
| `Email::<ChosenService>Transport` | One production outbound mailbox integration, selected in foundation milestone |
| `OutboundMessage` | Approved sender/recipient/subject/body, attempt, send response ID and timestamp |

No `ParkcrestAdapter` is needed. Its required fields, catchment rule, recipient and template are configuration for `Email::WaitlistComposer`. Mailbox transport code is shared. Collect neither extra family information nor attachments that Parkcrest does not request.

### Browser automation boundary

Rails classes: `Automation::Client` dispatches authenticated worker commands; `Automation::EventReceiver` validates callbacks; `Automation::HandoffService` authorizes short-lived browser access; `BrowserSession` and `HandoffRequest` track ownership, expiry and parent intervention.

Python layout and classes:

| Module | Classes / responsibility |
| --- | --- |
| `automation/onekare_worker/contracts.py` | Typed `RunCommand`, `RunEvent`, `PreparedResult`, `ExecutionResult`; protocol version 1 |
| `engine.py` | `AutomationEngine`: common command lifecycle, checkpoints and event emission |
| `sessions.py` | `BrowserSessionManager`: isolated session creation, reuse, expiry and cleanup |
| `actions.py` | `BrowserActions`: fill, select, click, approved upload and navigation primitives |
| `adapters/base.py` | `PlatformAdapter`: `prepare(context)` and `submit(context)` returning typed results |
| `adapters/registry.py` | `AdapterRegistry`: trusted code allowlist keyed by configured platform key |
| `adapters/public_form.py` | `PublicFormAdapter`: reusable conventional-form behavior, where validated |
| `adapters/<platform_key>.py` | Platform navigation/auth behavior only when the shared adapter is insufficient |
| `verification.py` | `VerificationHandler`: pause with reason and resume in the same session |
| `confirmation.py` | `ConfirmationCollector`: supported success/failure evidence, never guessed membership |
| `credentials.py` | `CredentialResolver`: redeem a scoped short-lived reference; never pass secrets to AI |

Adapter methods use shared actions; provider configuration supplies field mappings, centre IDs and URLs. Custom extensions must be reviewed code registered by key, not scripts supplied through configuration. Separate preparation from submission so filling a form cannot silently submit it before approval.

## 2. Frontend/backend feature contracts

Routes below are proposed contracts. Implement HTML responses and Turbo replacements, with 303 redirects after successful form mutations and 422 inline validation failures. JSON is required only for the worker boundary; browser pages do not need a second REST API. Auth/ownership checks apply to every mutation, frame refresh and handoff.

| Feature | Frontend ownership | Controller/actions and route contract | Backend objects / view contract |
| --- | --- | --- | --- |
| Welcome/info | `pages/home`, `pages/about`; shared header | `PagesController#home/#about`: `GET /`, `/about` | Public informational content |
| Account | Signup/login/reset views; shared form errors | `RegistrationsController#new/#create`: `GET /sign-up`, `POST /registrations`; `SessionsController#new/#create/#destroy`: `GET /login`, `POST/DELETE /session`; reset routes under `/passwords` | Authentication scaffold, `User`, `Session`; never expose password values |
| Parent profile | `profiles/edit`, contact form | `ProfilesController#edit/#update`: `GET /profile/edit`, `PATCH /profile` | `@user`: full name, email, local telephone number |
| Children | `children/index/new/edit`, `_form`, `_card` | `ChildrenController#index/#new/#create/#edit/#update`: `/children` resource routes | `@children`/`@child`: ID, full name, date of birth; child deletion deferred |
| Search/detail | `centres/index/show`, `_filters`, `_card`, `_program`; `filters_controller.js` | `CentresController#index/#show`: `GET /centres`, `/centres/:id` | `@results` from search and `@centre` presenter: location, care types, vacancy/source date, action label/URL |
| Dashboard | `applications/index`, `_card`, shared `_status_badge`, child selector | `ApplicationsController#index`: `GET /applications?child_id=...` | `@applications` with status presenters; only owned records |
| Start/wizard | `applications/new/edit`, `_child_step`, `_eligibility_step`, `_questions_step`; `wizard_controller.js` | `ApplicationsController#new/#create/#edit/#update`: `/applications` resource routes | `@application`, `@revision`, `@questions`, `@children`; server validates every saved step |
| Preparation/review | `applications/review`, `_answers`, `_email_preview` | `ApplicationPreparationsController#create`: `POST /applications/:application_id/preparation`; `ApplicationReviewsController#show`: `GET /applications/:application_id/review` | Review presenter with frozen content, missing fields and readiness |
| Approval/execution | Approval form with explicit action text; no client-side submission to provider | `ApplicationApprovalsController#create`: `POST /applications/:application_id/approval` | Submitted revision ID/digest checked against server state; coordinator records approval and schedules execution |
| Detail/history | `applications/show`, `_progress`, `_timeline`, `_outcome_form`; `application_progress_controller.js` | `ApplicationsController#show`: `GET /applications/:id`; `ApplicationOutcomesController#create`: `POST /applications/:application_id/outcomes` | Execution state and reported outcome displayed separately; attributed events and allowed actions |
| External tracking | External action form, return prompt | `ExternalApplicationsController#create`: `POST /external_applications`; `ApplicationExternalVisitsController#create`: `POST /applications/:application_id/external_visits` | Create/reuse tracking entry; record activity and redirect only to verified/configured destination; “Not yet” changes no status |
| Provider accounts | `connections/index`, `provider_connections/new/edit`; masked connection cards | `ConnectionsController#index`: `GET /connections`; `ProviderConnectionsController#new/#create/#edit/#update/#destroy`: `/provider_connections` resource routes | Platform/login origin, connection ID, connected/verification-needed/revoked status; credentials are write-only |
| Mailbox connection | Connect/disconnect button, sender identity | `MailboxAuthorizationsController#create/#callback`: `POST /mailbox_authorization`, `GET /mailbox_authorization/callback`; `MailboxConnectionsController#destroy`: `DELETE /mailbox_connections/:id` | Authorized sender email and connection status; OAuth state bound to user/session |
| Verification handoff | `handoffs/show`, expiry/retry state; `handoff_controller.js` | `HandoffsController#show/#resume`: `GET /applications/:application_id/handoff`, `POST /applications/:application_id/handoff/resume` | Owned short-lived handoff view; worker must recheck verification instead of trusting a client “complete” flag |

Poll the application's authenticated Turbo Frame every few seconds only while work is active, with backoff and stop on completion/navigation. This avoids adding Action Cable deployment work to MVP. Polling application progress is not inbox monitoring or provider waitlist polling.

### Shared form and presenter shapes

- Child input: `child_profile[full_name]`, `child_profile[date_of_birth]` (ISO date).
- Application creation: `care_application[child_profile_id]`, `[centre_id]`, optional `[care_program_id]`. Server derives channel and enabled configuration; the browser cannot override capabilities.
- Wizard input: revision number for concurrency checks plus `answers` keyed by canonical field names. Preserve dates as dates, not timezone-shifted timestamps.
- Configured question: `{ key, label, type, required, options, help_text }`. Allowlisted types: text, date, select, boolean, telephone. UI renders the schema; server enforces it. Do not trust browser-supplied question definitions.
- Parkcrest answer keys: `child.full_name`, `child.date_of_birth`, `parent.full_name`, `parent.local_phone`, `eligibility.catchment` (`parkcrest`, `aubrey`, `other`, `unknown`), `eligibility.confirmed` and `parent.local_phone_confirmed`. Only eligible, explicitly confirmed answers can advance.
- Review presenter: `revision_id`, `content_digest`, `configuration_version`, `sender`, `recipient`, `subject`, `body` (email) or ordered form answers (browser), `missing_fields`, `can_approve`, `blocking_reason`. Never serialize stored credentials.
- Status presenter: `execution_state`, `outcome`, `label`, `source_label`, `updated_at`, `allowed_actions`, `uncertainty_message`. All cards and detail pages use it; do not independently derive status text in JavaScript.
- Outcome form: `outcome`, optional `note`, and optimistic lock version. Parent-supplied source/actor fields are ignored; the server sets them.

## 3. Schema contract and invariants

Use normal foreign keys, timestamps and indexes. JSONB is appropriate for versioned mappings and answer snapshots, not a substitute for ownership relations. Authentication scaffold may use its conventional field names; presenters expose the agreed UI names.

| Model | Essential fields / relationships |
| --- | --- |
| `User`, `Session` | Email/password digest, full name, local phone; sessions belong to user |
| `ChildProfile` | User FK, full name, date of birth |
| `Provider`, `Centre`, `CareProgram` | Centre belongs to provider when known; program belongs to centre; source IDs/contact/location/service attributes and vacancy observation timestamps |
| `ImportRun` | Source, fetched timestamp, validation/error counts and completion status; no credentials in source logs |
| `IntegrationPlatform` | Unique key, adapter key, allowed origins |
| `ProviderConfiguration` | Provider FK, optional platform FK, support status and current version FK |
| `ProviderConfigurationVersion` | Configuration FK, unique version, nullable workflow until classified, settings JSONB, validation record/timestamp; immutable once used |
| `ProgramIntegration` | Program FK unique for active assignment, configuration FK; share one configuration across programs |
| `ProviderConnection`, `MailboxConnection` | User FK, platform/origin or mailbox service/sender, encrypted secrets, status and token expiry where applicable |
| `CareApplication` | User, child and centre FKs; optional program/config version/connection FKs; channel; execution state; outcome/source; current revision FK; lock version; optional archived timestamp |
| `ApplicationRevision` | Application FK, unique revision number, configuration version, eligibility/answers/message snapshot, sending connection identity and digest |
| `Approval` | Application/revision/user FKs, approved digest/configuration/sender identity, approval and invalidation timestamps |
| `ExecutionAttempt` | Application/revision/approval FKs as applicable, phase (`prepare`/`submit`), operation UUID, status, lease/checkpoint, started/finished timestamps; submission requires approval |
| `ApplicationEvent` | Application FK, event type, prior/new values, source, user or attempt FK, optional note/evidence FK, occurred/recorded timestamps, external event ID for deduplication |
| `OutboundMessage` | Application/revision/attempt/mailbox FKs; exact approved sender, recipient, subject/body; result reference and sent timestamp |
| `BrowserSession`, `HandoffRequest` | Owner/application/run association, opaque session reference, reason, expiry, state; encrypted browser state when retained |
| `SubmissionEvidence` | Attempt FK, kind, confirmation reference and optional private object reference; retention metadata |

For BC imports, validate row identity before defining unique keys: one source facility can have multiple service rows. Preserve source facility and service identifiers rather than deduplicating by name or treating every CSV row as a new centre. Do not guess provider ownership from names; nullable provider linkage is allowed for discovery records.

Execution states: `draft`, `preparing`, `needs_parent_input`, `ready_for_review`, `approved`, `executing`, `completed`, `failed`, `uncertain`. External-only tracking has no worker run. Display outcome captures `not_submitted`, `submitted`, `waitlist_request_sent`, `waitlisted`, `offer_received`, `enrolled`, `rejected`, `offer_declined`, `withdrawn`. Use distinct rejection/declined values so the parent can distinguish a provider rejection from their own declined offer.

Only observed submission may set automation-sourced `submitted`; accepted mail sending sets `waitlist_request_sent`. Later outcomes are parent-reported in MVP. An uncertain run remains uncertain even if the parent reports an outcome. The coordinator serializes writes and prevents late execution events from regressing later parent outcomes. Corrections append events.

Reuse one active tracking entry per user/child/centre/program target with a database uniqueness strategy that handles null program IDs. Archive an old application explicitly before starting a new cycle. Approval uniqueness and a database-backed execution claim prevent duplicate dispatch; callbacks are idempotent. External services can still leave ambiguous results, so never claim exactly-once remote submission.

## 4. Worker protocol and approval boundary

Use Rails jobs for orchestration and a private authenticated worker HTTP interface for browser execution. Rails persists an attempt before dispatch; the worker acknowledges quickly and executes asynchronously. A stable run/command ID makes dispatch retries idempotent. Workers must share a durable command claim mechanism when scaled beyond one process; an in-memory deduplication set is insufficient.

Proposed worker endpoints: `POST /v1/runs` to prepare; `POST /v1/runs/:id/submit` for an approved revision; `POST /v1/runs/:id/resume` after handoff; `GET /v1/runs/:id` for reconciliation. Rails receives authenticated callbacks at `POST /internal/automation/events` through `Internal::AutomationEventsController#create`. None are public parent-facing endpoints.

Command fields: `protocol_version`, `command_id`, `run_id`, `application_id`, `phase`, `revision_id`, `content_digest`, `configuration_version_id`, validated configuration snapshot, necessary answers, opaque session reference, and scoped credential reference if needed. Submit additionally carries a short-lived authorization bound to the current approval and digest. Secret redemption is restricted to that run/user/platform, uses an authenticated private channel and never returns through the parent UI.

Event fields: `protocol_version`, unique `event_id`, `run_id`, `command_id`, monotonic sequence, event type, checkpoint, reason/error code and optional private evidence reference. Types: `prepared`, `needs_parent_input`, `submission_confirmed`, `failed`, `uncertain`, `expired`. Validate callback identity and record deduplication before updating state; ignore stale regressions. Callbacks cannot select another user's application.

Preparation may navigate/login/fill but cannot submit. Worker presents its actual prepared answers to Rails for review. If session expiry requires re-preparation, compare the answers/configuration against the approved revision; meaningful changes return to review. CAPTCHA/MFA handoffs pause the same isolated browser and block concurrent worker interaction. Parent verification never substitutes for application approval.

A submit timeout after a click/send is uncertain, not a retryable failure. Safe pre-submission failures can retry under coordinator control. Parent outcomes never dispatch a worker. Mail send uses the same approval/attempt rules without the browser protocol.

## 5. Assignable work packages

Each row is a ticket or small paired PR. FE/BE owners can work concurrently after the contract/fixture dependency is merged.

| ID | Frontend task | Backend / integration task | Depends on | Done when |
| --- | --- | --- | --- | --- |
| F0 | Agree screen names, field labels, error/empty/loading states and shared partials | Lock names/routes/statuses; choose initial mailbox service and handoff hosting; define worker protocol fixture JSON | None | Team has one contract, fictional fixture pack and owners for migrations/routes/layout |
| F1 | Shared shell/header/sidebar, welcome/info, reusable form errors and status badge | Install durable job backend and document web/job/worker startup; isolate test DB; make CI boot without real credentials | F0 | UI shell works; restart does not discard queued jobs; isolated test setup documented |
| F2 | Signup/login/reset, parent contact and child forms | Authentication scaffold and ownership enforcement; user/session/child migrations and CRUD | F0 | Parent can manage own children; another user's identifiers are rejected |
| F3 | Search filters, daycare cards and program details with clear action labels | Directory/config models, BC importer, search/presenters, unknown-provider fallback | F0 | Repeat import is idempotent; unknown daycares remain visible; no invented availability or application URLs |
| F4 | Dashboard, application detail/timeline, external return prompt and outcome form | Application/events model, tracking creation/reuse and parent outcome service | F2, F3 | Link clicks never mean submitted; parent outcomes show source and cannot send anything |
| F5 | Wizard question renderer, eligibility step, review and approval UI | Immutable revisions, config validation, coordinator, approval/attempt model and preparation/execution jobs | F2, F3, F4; durable queue from F1 | Missing answers block; changed content invalidates approval; duplicate clicks produce one accepted execution claim |
| F6 | Connection page and mailbox connect/disconnect/sender states | One outbound OAuth service, encrypted token lifecycle, fake transport and deterministic Parkcrest configuration/template | F2, F5 | Minimal send authorization works; disconnected mailbox blocks approval/execution; secrets never returned |
| F7 | Parkcrest review, request-sent and uncertain-send states | Generic approved-email sender and evidence recording | F6 | Eligible fictional case reaches exactly “Waitlist request sent”; ineligible/unknown catchment blocks; uncertain send never auto-retries |
| F8 | Progress polling and handoff UI (active/expired/reconnecting states) | Worker protocol/client/callbacks, isolated sessions, shared actions, handoff authorization and controlled public-form adapter | F5, F1 | Owned fixture form prepares, pauses/resumes and submits only with valid approval; callbacks deduplicate |
| F9 | YWCA missing-question/CAPTCHA/review flow | Validate YWCA platform/configuration and confirmation signals; reuse F8 infrastructure | F8 | Owned YWCA-shaped fixture passes end to end; live provider support remains disabled until validated |
| F10 | Saved credential form, masked account status and verification flow | Encrypted provider credential lifecycle; authenticated-platform adapter and YMCA config validation | F2, F8 | Login/verification works in owned portal fixture; credentials/session never leak across parents; rotation/disconnect blocks stale runs |
| F11 | Polish all three flows and external tracking; keyboard/mobile/error-state review | Cross-feature recovery/authorization tests, source attribution, provider enablement checklist and setup docs | F7, F9, F10 | Demo succeeds with fictional data and test targets; automated and parent-reported statuses remain distinct |

Frontend acceptance for every ticket includes keyboard-accessible controls, field labels/errors, pending/disabled states, empty states and preservation of input on validation errors. Backend acceptance includes ownership checks, input validation, state-transition tests where meaningful, and no secrets in responses/logs.

## 6. Delivery order and integration checkpoints

1. **Contract and foundation:** F0 first; then F1, F2 and F3 can progress independently. Validate provider feasibility early; do not defer discovering portal restrictions to the final milestone.
2. **Useful app without automation:** F4 produces searchable daycare listings, owned profiles and manual application tracking. FE can use seeded status/history fixtures while services are implemented.
3. **First automated vertical slice:** F5 → F6 → F7. This establishes approval, credentials for email, sending and accurate result handling through Parkcrest. Use fake transport first, then an authorized test mailbox.
4. **Browser automation:** F8 establishes shared infrastructure; F9 and F10 can proceed in parallel once its interface is stable. YMCA adds login behavior rather than a separate workflow engine.
5. **Integration:** F11 joins the UI and services and verifies all required states before enabling real-provider actions.

No calendar estimate is assumed until owners, availability and deadline are known. Track completion by these checkpoints rather than claiming all providers take equal effort. If schedule is tight, ship discovery/manual tracking and Parkcrest first; keep incomplete browser capabilities disabled.

## 7. Shared fixtures and verification

Maintain fictional fixtures for: two parents (authorization boundary), multiple children, an unknown daycare, each of the three supported configurations, every dashboard outcome, incomplete eligibility, expired connection, failed/uncertain send and expired browser handoff. Keep the same canonical field names in UI seed records and worker contract fixtures.

Backend checks: cross-user access, eligibility and missing fields, immutable approval content, concurrent execution claims, duplicate/out-of-order callbacks, ambiguous delivery, parent correction history and repeat BC imports. Integration checks: controlled form/portal and test mailbox only; no real daycare submissions in CI. Frontend system checks cover one Parkcrest journey, one external-tracking journey, and browser-handoff states using worker fixtures.

Smoke checks must show: one child's data never fills another child's application; edited profiles do not rewrite approved snapshots; a parent status update does not enqueue work; email acceptance does not mean waitlist membership; one application's delayed result cannot regress another state. CI cannot require production Lakebase, mailbox credentials or real-family data.

Deferred: inbox read permissions, reply classifiers, registration-link extraction, enrollment paperwork, catchment geocoding, a generic AI agent submitting unknown forms, full provider admin UI and broad mailbox-provider support. Additional UI polish must not silently introduce one of these integrations.
