# OneKare

OneKare is an AI-assisted daycare application platform. Parents create one profile, and OneKare prepares and submits supported daycare forms and email waitlist requests after parent review and approval.

## MVP architecture and scope

See [the architecture and implementation plan](docs/mvp-architecture.md) for the shared automation engine, reusable platform adapters, database-backed provider configuration and delivery milestones.

For assigning team work, use the [frontend/backend implementation plan](docs/implementation-plan.md). It defines matching screens, routes, models, service classes, worker contracts, task dependencies and acceptance criteria.

The initial scenarios are YWCA public forms, YMCA authenticated applications using securely stored provider credentials, and Parkcrest Child Care Society email-only school-age waitlist requests. Parkcrest ends at **Waitlist request sent**; inbox monitoring and subsequent enrollment are outside the MVP.

## Technology stack

- Ruby on Rails + Hotwire
- Python + Playwright for browser automation
- Databricks Foundation Model APIs for form-field mapping
- Databricks Lakebase for PostgreSQL storage

## Teammate onboarding

Clone the repository and check out a branch containing the frontend initialization. Generated Rails and Hotwire files are shared through Git once committed and pushed; each teammate installs dependencies and supplies local configuration. Do not run `rails new` or rerun the Hotwire installers after cloning.

### First-time setup

1. Install the Ruby version specified in `.ruby-version`, Bundler, Git and PostgreSQL client libraries using the platform setup below.
2. From the repository root, run `bundle install` to install the versions in `Gemfile.lock`.
3. Copy `.env.example` to `.env.development.local` without overwriting an existing local file. Add your authorized Lakebase development connection URL and uncomment `DATABASE_URL`. See [Environment variables](#environment-variables) for macOS and Windows commands.
4. Run `bin/rails db:prepare`, then `bin/rails server`. On Windows, use `ruby bin/rails db:prepare` and `ruby bin/rails server`.
5. Open [localhost:3000](http://localhost:3000).

Docker, Node.js, npm and the Python/Playwright dependencies are not required just to work on Rails screens. The Python and Databricks CLI setup sections below are for work on their corresponding integrations. Lakebase supplies the database server; local PostgreSQL client libraries are still needed by the Ruby database driver.

### Everyday development

Start Rails from the repository root:

```bash
bin/rails server
```

Use `ruby bin/rails server` on Windows. After pulling changes, run `bundle install` when `Gemfile` or `Gemfile.lock` changes, and `bin/rails db:prepare` when database migrations are added. Restart Rails after changing local environment variables. Database commands must target a development database, never production.

### Shared files versus local files

Commit application code, generated Hotwire files, `Gemfile`, `Gemfile.lock`, documentation and the placeholder-only `.env.example`. Keep real credentials out of committed files.

The repository's `.gitignore` excludes local `.env` files, Rails decryption keys, logs, temporary files, local uploads, Python virtual environments, browser authentication state in `automation/playwright/.auth/`, and installed dependency directories. These files are not distributed when teammates clone the repository. If a future feature needs Rails encrypted credentials, distribute its decryption key through a secure channel rather than Git.

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

Rails loads `.env.development.local` automatically using `dotenv-rails`. This file is ignored by Git and is not loaded in the test environment. `.env.example` contains only placeholders and can be committed.

From the repository root, install the dependencies from the existing Gemfile (do not run `rails new` again):

```bash
bundle install
```

Copy `.env.example` to `.env.development.local` **only if your local file does not already exist**. On macOS:

```bash
cp -n .env.example .env.development.local
```

On Windows PowerShell:

```powershell
if (!(Test-Path .env.development.local)) {
  Copy-Item .env.example .env.development.local
}
```

Open `.env.development.local`, replace the sample URL with your dedicated Lakebase **development** connection URL, and remove the leading `#` from `DATABASE_URL`. Keep the value single-quoted and preserve the connection's SSL options. Do not paste real credentials into `.env.example`, `config/database.yml`, or Git. The Databricks model variables are optional until that integration is implemented.

Existing shell environment variables take precedence over the file. If you previously exported an old URL, run `unset DATABASE_URL` on macOS or `Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue` in PowerShell before starting Rails.

Start the app:

```bash
bin/rails db:prepare
bin/rails server
```

On Windows, use `ruby bin/rails db:prepare` and `ruby bin/rails server`. Open http://localhost:3000. Restart Rails after changing environment values. `db:prepare` applies schema changes, so use a dedicated development database. A local PostgreSQL server is unnecessary when using Lakebase; the `pg` gem still requires PostgreSQL client libraries. If its native build cannot locate them on macOS, run `bundle config set --local build.pg --with-pg-config="$(brew --prefix libpq)/bin/pg_config"` and retry `bundle install`.

Configure a separate test database before running database tests; never point tests at the development or production database. Use `.env.test.local` for test-specific connection settings, and do not export a development `DATABASE_URL` into the test process. Production receives its environment variables from the deployment environment, not these local files.

Use fictional parent and child data during development and demos. Lakebase credentials may expire; if authentication stops working, update the local URL with fresh credentials and restart Rails.

## Frontend development (Hotwire)

Importmap, Turbo and Stimulus are initialized in this repository. After pulling these files, run `bundle install`, configure the development database as above, and start `bin/rails server` (or `ruby bin/rails server` on Windows). No Node.js, npm install, JavaScript build or separate frontend server is required by the current setup.

Rails serves HTML templates, styles and JavaScript. Importmap tells the browser where JavaScript modules live without a bundling step. Turbo enhances navigation and form interactions, while Stimulus attaches behavior such as dropdowns to HTML elements. The shared layout loads the JavaScript entrypoint, which starts Turbo and registers the Stimulus controllers.

| File or directory | Purpose |
| --- | --- |
| `app/views/` | Rails HTML templates and layouts |
| `app/assets/stylesheets/application.css` | Application styles |
| `app/javascript/application.js` | JavaScript entrypoint; loads Turbo and Stimulus controllers |
| `app/javascript/controllers/` | Stimulus controllers for interactive behavior |
| `config/importmap.rb` | JavaScript module mappings; automatically pins controllers |
| `app/views/layouts/application.html.erb` | Loads styles and JavaScript through `javascript_importmap_tags` |

Generate a controller with `bin/rails generate stimulus dropdown`, then connect it to HTML using `data-controller="dropdown"`. Use `ruby bin/rails generate stimulus dropdown` on Windows. The generated `hello_controller.js` is an optional starter example; attaching `data-controller="hello"` to an element replaces its text with `Hello World!` as a quick browser check.

The following initialization commands have **already been run**. Teammates should use the generated files rather than rerunning the installers:

```bash
bin/rails importmap:install
bin/rails turbo:install
bin/rails stimulus:install
```

`bin/importmap audit` runs the JavaScript dependency audit used by CI and requires network access. On Windows, use `ruby bin/importmap audit`.

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
