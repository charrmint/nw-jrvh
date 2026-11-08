# Running OneKare locally (merged front end + application automation)

Commands are for Windows PowerShell from the project folder. Use `ruby bin/rails ...` (not `bin/rails`).

## 0. What the three demo daycares need
| Daycare | How OneKare applies | Needs |
|---|---|---|
| **Beach YMCA** | browser automation (Python + Playwright) | your YMCA portal login saved in **Settings** |
| **Beyond Care** | browser automation (public form) | nothing saved; Playwright installed |
| **Parkcrest** | email sent through Gmail | **Connect Gmail** in Settings + `PARKCREST_TEST_RECIPIENT` |

Every application also needs the child's **date of birth** and a completed **general application**
(the "Edit child info" link on the Children page).

## 1. Database  (the important part)
The provider setup lives in specific `daycares` rows (Beyond Care = BC facility 415, Parkcrest = BC facility 335,
plus a Beach YMCA row). Pick ONE:

**A. Use the same Lakebase development database as your teammate (easiest).** Ask him for the `DATABASE_URL`.
Those rows already exist there, so just run `ruby bin/rails db:migrate`.

**B. Use your own empty database.**
```powershell
ruby bin/rails db:prepare
$env:BC_DAYCARE_FACILITY_IDS="415,335"    # import only the two BC daycares (omit to import all of BC)
ruby bin/rails daycares:import_bc
Remove-Item Env:BC_DAYCARE_FACILITY_IDS
ruby bin/rails demo:setup_providers       # configures Beach YMCA, Beyond Care and Parkcrest (safe to repeat)
```
(`demo:setup_providers` is new; it does what the provider migrations do but by facility id, so it works on any database.)

## 2. `.env.development.local`  (never commit; copy from `.env.example`)
```
DATABASE_URL='postgresql://...'                     # from your teammate (option A) or your own DB
GOOGLE_OAUTH_CLIENT_ID='...'                        # from your teammate
GOOGLE_OAUTH_CLIENT_SECRET='...'                    # from your teammate
PARKCREST_TEST_RECIPIENT='you@example.com'          # an address YOU control. Never Parkcrest's own address.
PYTHON='C:/full/path/to/nw-jrvh/automation/.venv/Scripts/python.exe'
# Only needed if a form mapping has to be regenerated live:
# DATABRICKS_HOST=...   DATABRICKS_TOKEN=...   DATABRICKS_MODEL_ENDPOINT=...
```
`PYTHON` matters on Windows: Rails otherwise runs `python3`, which usually doesn't exist there.

## 3. Python / Playwright (for Beach YMCA and Beyond Care)
```powershell
py -m venv automation\.venv
.\automation\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install playwright
python -m playwright install chromium
```

## 4. Gmail (for Parkcrest)
Gmail sending uses Google OAuth in your teammate's Google test project:
1. Send him your Google account email so he can add you as a **test user**.
2. The app must run on **port 3000**: the redirect address is fixed at `http://localhost:3000/gmail/oauth/callback`.
3. In the app: **Settings → Connect Gmail**, approve "send email" only.

## 5. Start and try it
```powershell
bundle install
ruby bin/rails server
```
1. Sign up, then add a child (Children → Add a child) and fill in **Edit child info**.
2. Settings: save the YMCA login and connect Gmail.
3. Search for **Beach YMCA**, **Beyond Care** or **Parkcrest** → open it → **Apply automatically**.
4. The status under the button and on the **Applications** page now updates by itself while the application is Queued/Sending.

Background jobs run inside the Rails process in development, so leave the server running until the status finishes.
For a visible browser window while testing YMCA, set `HEADLESS=false`.

## Troubleshooting
- *"Connect the YMCA account before applying"* → save the YMCA login in Settings.
- *"Connect Gmail before applying"* → Settings → Connect Gmail.
- *"PARKCREST_TEST_RECIPIENT must be configured"* → add it to `.env.development.local` and restart.
- *"Complete this child's profile and general application"* → add a date of birth and finish Edit child info.
- Beyond Care / Parkcrest missing from search → database step 1B (or you are on a different DB than your teammate).
- Gemfile.lock platform error on Windows → `bundle lock --add-platform x64-mingw-ucrt`, then `bundle install`.
