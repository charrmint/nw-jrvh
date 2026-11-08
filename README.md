# OneKare

OneKare is an AI-assisted daycare application platform. Parents create one profile, and OneKare prepares and submits supported daycare forms and email waitlist requests after parent review and approval.

## MVP architecture and scope

See [the architecture and implementation plan](docs/mvp-architecture.md) for the shared automation engine, reusable platform adapters, database-backed provider configuration and delivery milestones.

The initial scenarios are YWCA public forms, YMCA authenticated applications using securely stored provider credentials, and Parkcrest Child Care Society email-only school-age waitlist requests. Parkcrest ends at **Waitlist request sent**; inbox monitoring and subsequent enrollment are outside the MVP.

## Technology stack

- Ruby on Rails + Hotwire
- Python + Playwright for browser automation
- Databricks Foundation Model APIs for form-field mapping
- Databricks Lakebase for PostgreSQL storage

## macOS setup

The commands below assume Apple Silicon and Homebrew. Intel Macs can use the equivalent Homebrew paths under `/usr/local`.

### Required tools

```bash
brew install mise
echo 'eval "$(mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc

mise use -g ruby@3.4
gem install rails

python3 --version
git --version
```

### Playwright

Playwright may be installed globally or inside a project virtual environment. A virtual environment is recommended for project isolation.

```bash
mkdir -p automation
python3 -m venv automation/.venv
source automation/.venv/bin/activate
python -m pip install --upgrade pip
python -m pip install playwright
python -m playwright install chromium
python -m playwright --version
```

If Playwright was installed globally, use `python3` instead of `python` in the verification commands.

### PostgreSQL client (`psql`)

This installs the PostgreSQL client tools for testing Lakebase connections. A local PostgreSQL server is not required.

```bash
brew install libpq
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
echo 'export PATH="/opt/homebrew/opt/libpq/bin:$PATH"' >> ~/.zshrc
psql --version
```

### Databricks CLI

```bash
brew install databricks/tap/databricks
databricks version
databricks auth login
```

## Windows setup

Install these prerequisites first:

- RubyInstaller with Ruby 3.4 and the MSYS2 toolchain
- Python 3.13
- Git for Windows
- PostgreSQL client tools (the PostgreSQL installer or another trusted PostgreSQL distribution)
- Windows Terminal or PowerShell

After installing RubyInstaller, open a new PowerShell window:

```powershell
ruby --version
gem install rails
rails --version
python --version
git --version
```

### Playwright

```powershell
mkdir automation
py -m venv automation\.venv
.\automation\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install playwright
python -m playwright install chromium
python -m playwright --version
```

If PowerShell blocks activation scripts, run PowerShell as your user and execute:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Databricks CLI

With `winget` available:

```powershell
winget install Databricks.DatabricksCLI
databricks version
databricks auth login
```

Verify that `psql --version` works after installing the PostgreSQL client. The exact command may depend on which PostgreSQL distribution was selected.

## Environment variables

Create local environment values for development. Never commit tokens, database credentials, or real family information.

```dotenv
DATABASE_URL=postgresql://...
DATABRICKS_HOST=https://your-workspace-host
DATABRICKS_TOKEN=your-secret-token
DATABRICKS_MODEL_ENDPOINT=your-model-endpoint
```

Use fictional parent and child data during development and demos.

## Verify the local toolchain

### macOS

```bash
ruby -v
which ruby
rails --version
python3 --version
python3 -m playwright --version
psql --version
databricks version
git --version
```

### Windows PowerShell

```powershell
ruby --version
rails --version
python --version
python -m playwright --version
psql --version
databricks version
git --version
```

## Safety and MVP boundaries

- Use fictional family data for the hackathon.
- Respect daycare website terms and anti-automation controls.
- Do not bypass CAPTCHAs or access restrictions.
- Require parent review before any application is submitted.
- Completing a form does not guarantee that a daycare received the application or added the child to an official waitlist.
