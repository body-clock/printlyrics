# Working on PrintLyrics

PrintLyrics finds songs through LRCLIB or accepts pasted lyrics, then creates
shareable, print-optimized lyric sheets. Only the homepage and the two printing
guides are public and indexable; saved lyric pages and songbooks are separate,
token-addressed, and excluded from indexing. There is no public song catalog.

The application uses Rails 8.1, Ruby 4.0.5, SQLite, server-rendered ERB,
Turbo/Stimulus, importmaps, and Tailwind CSS. Treat `.ruby-version`, `Gemfile.lock`,
and configuration files as the source of truth for versions and tooling.

## Development and verification

- Follow [README.md](README.md) for setup. `bin/setup --skip-server` prepares
  the app; `bin/dev` runs Rails and the Tailwind watcher.
- The developer keeps `bin/dev` running in their own terminal, and it writes
  `tmp/pids/server.pid`. Never start a server on port 3000 and never signal the
  PID in that file: it is their `bin/dev` puma, and killing it ends their whole
  session because foreman tears down the group. For browser verification, point
  the browser at the server already running on `http://127.0.0.1:3000` and leave
  it alone. If nothing is listening, ask before starting anything; if a separate
  server is genuinely needed, give it its own port and `--pid` file rather than
  the shared one.
- Use the repository binstubs and Bundler. Assets build without Node.js;
  there is no Yarn, RSpec, or JavaScript unit-test setup to assume.
- Focused tests: `bin/rails test test/models/lyric_test.rb`; append `:LINE`
  to select a test. All non-system tests: `bin/rails test`.
- Browser tests: `bin/rails test:system` (Selenium with headless Chrome).
- Ruby style: `bin/rubocop path/to/changed_file.rb`. Asset verification:
  `bin/rails assets:precompile`.
- Security checks: `bin/brakeman --no-pager`, `bin/bundler-audit`, and
  `bin/importmap audit`. Dependency audits require network access.
- `bin/ci` runs the local pipeline in `config/ci.rb`, including setup and
  test database seed replanting. GitHub checks live in `.github/workflows/ci.yml`.
- Run checks relevant to the change. Report what passed, what could not run,
  and any remaining limitation; documentation-only edits need link and diff
  checks rather than the application test suite.

## Read when relevant

- [Rails guidelines](docs/rails_guidelines.md): read relevant sections before
  changing Rails code, JavaScript, styles, or tests.
- [Product direction](PRODUCT.md): visual design, print experience, and
  accessibility. Use current routes and tests to establish supported flows;
  references to URL extraction in product prose are not implemented features.
- [Organic search operations](docs/organic-search-operations.md): indexing,
  analytics contracts, and operational procedures.
- [README.md](README.md): retention, deployment, and release workflow.

## Working conventions

- Keep changes focused on the requested behavior and preserve unrelated work.
  Follow nearby conventions before introducing a dependency or abstraction.
- Preserve the manual-entry path when search is unavailable. Treat screen
  preview and printed output as equally important product surfaces.
- Update guidance when commands or product contracts change. Plans under
  `docs/plans/` provide historical context; verify them against current code.
- Release Please manages `CHANGELOG.md` and `version.txt`; ordinary feature
  changes should not manually bump release files.
