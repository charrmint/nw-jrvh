# MVP general application: provider-neutral questions

Parents maintain a child profile and complete one general application per child before choosing a daycare. The general application selects the child and does not repeat child identity fields. It asks reusable questions in provider-neutral language. Provider credentials stay in Settings. The parent later chooses a daycare and clicks **Apply automatically**; the submission runs without a separate review or approval step.

## Child profile

| Field ID | Parent question |
| --- | --- |
| `child.first_name`, `child.last_name` | Child's first and last name |
| `child.date_of_birth`, `child.expected_due_date`, `child.birthdate_unknown`, `child.birthdate_estimated` | Birthdate, expected due date, or explicitly unknown birthdate |

## General application

| Field ID | Parent question |
| --- | --- |
| `care.preferred_start_date` | When would you like care to start? |
| `care.preferred_schedule` | Preferred schedule: any available, full time, part time, before school, after school, or before and after school |
| `school.name` | Which school does the child attend or expect to attend? (school-age care) |
| `school.catchment` | Which school catchment does the child live in? Parkcrest, Aubrey, Cascade Heights or Inman Elementary, another catchment, or unknown |
| `child.support_required` | Does the child need support to participate successfully in a program? Yes / No |
| `parent.first_name`, `parent.last_name` | Primary guardian's first and last name |
| `parent.email`, `parent.local_phone` | Email and local telephone number |
| `parent.date_of_birth` | Primary guardian's birthdate |
| `parent.mailing_street`, `parent.mailing_city`, `parent.mailing_province`, `parent.mailing_postal_code`, `parent.mailing_country` | Mailing address |
| `parent.second_guardian_name`, `parent.second_guardian_email`, `parent.second_guardian_phone` | Optional second parent/guardian |
| `parent.application_sms_consent` | Optional consent to OneKare text updates about applications |
| `priority.affiliations` | Optional organizations the family works for, studies at, lives in, or is affiliated with; "none" is an explicit answer |
| `priority.categories` | General care priority categories: child care employee, young-parent program, community support program, transferring care, current sibling in child care, or former sibling in child care; "none" is an explicit answer |

## Provider translation for MVP

- The general form does not ask YMCA or YWCA branded priority questions. On their provider forms, uncollected provider-specific priority and marketing-SMS answers default to **No**. Generic affiliations and categories are retained for future mapping but do not automatically claim a provider-specific priority.
- Catchment and support answers are factual eligibility/application questions. They are never fabricated or set to Yes by configuration. Parkcrest requires a parent-selected Parkcrest or Aubrey catchment; unknown or another catchment blocks its email request.
- The browser inspects the live provider form on every application. If its field inventory differs from the saved inventory, Databricks generates an updated mapping and allowed defaults, and the configuration changes. If unchanged, the current configuration maps the newly observed controls. The later daycare submission stores the normalized answers, current form observation, mapping used, submitted content and status.
- YMCA portal username/email and password remain in Settings, encrypted at rest. Parent verification/CAPTCHA occurs during submission. A Parkcrest email sent through the parent's connected mailbox records **Waitlist request sent**, not waitlist membership.

The YMCA screenshots supplied by the user informed the original form inventory. Provider-specific priority choices are deliberately deferred in the MVP general application. Sources: [YWCA form](https://ywcabc.org/programs/child-care/waitlist-application) and [Parkcrest FAQ](https://www.parkcrestchildcaresociety.ca/about/faq/). Verify the current YMCA portal again before enabling browser automation.
