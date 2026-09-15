# Rails guidelines

## Models and domain objects

- Prefer cohesive objects named for product concepts, with meaningful methods,
  over generic `*Service`, `*Manager`, or `*Handler` classes. Keep persistence
  and domain invariants in Active Record models; use plain Ruby objects for
  behavior that does not need a table.
- Existing examples include `Lyric` for stanzas and retention, `Song` for
  sourced-song demand, `LrcLibResult` for source data, and `LyricPageCreation`
  for coordinating saved pages. `app/models/` also contains
  form and workflow objects; directory placement alone does not define a layer.
- Controllers and forms handle input and responses; application workflows
  coordinate domain operations; domain objects own business rules; clients
  handle external transport. Keep dependencies directed toward domain and
  infrastructure code. Do not pass requests, params, sessions, or controller
  objects into domain code, or read `Current` there; pass explicit values.
- Use `ActiveModel::Model` when a PORO needs validation or form integration,
  as `SongSearch` does. Extract a query, presenter, or workflow only when it
  has a cohesive responsibility; do not add architectural scaffolding by default.
- Reserve callbacks for record integrity, such as tokens, slugs, normalization,
  and defaults. Keep external requests and multi-record operations explicit.
- Maintain existing objects without an unrelated migration. When extending
  mixed responsibilities, move the relevant behavior to its appropriate layer
  rather than spreading HTTP concerns or side effects further into models.

## Controllers and views

- Controllers handle strong parameters, resource lookup, domain calls, and
  HTTP responses. Keep calculations, parsing, and multi-record workflows in
  appropriate objects. Prefer resource-oriented routes and existing conventions.
- Preserve the `lyric_entry` Turbo frame and editable input on failed forms.
  Follow the existing `:unprocessable_content` status for validation failures
  and `:service_unavailable` for temporary source failures.
- Keep queries and business calculations out of ERB. Use helpers for simple
  formatting, partials with explicit locals for repeated markup, and a presenter
  if view-specific logic becomes substantial.
- Put user-visible copy in `config/locales/en.yml` using the existing I18n
  structure. Escape pasted and fetched lyrics and metadata; do not mark them
  `html_safe`. Preserve line and stanza boundaries when rendering lyric text.

## Product and data contracts

- Searching and selecting a result populate an editable form without creating
  `Lyric` or `Song` records. Persist a page only when the user generates it.
  Manual entry must continue to work without LRCLIB or title/artist metadata.
- Permit editable title, artist, and lyrics. Derive source attribution and
  catalog metadata from `SongCatalogToken`, not submitted source URLs or hidden
  metadata fields. Preserve signature purpose and expiration checks; invalid
  or expired catalog tokens fall back to an unattributed manual page.
- Keep saved display text separate from verified catalog metadata. Creating a
  sourced lyric and promoting its song must succeed together. Preserve the
  transaction, uniqueness handling, and concurrency protection in
  `LyricPageCreation` when changing this workflow.
- Saved pages use opaque tokens, remain `noindex, nofollow`, and never appear
  in the sitemap. Tokens are shareable URLs, not an authentication system.
- Active page visits renew the 180-day retention window. Expired or unknown
  tokens return to the form. Keep cleanup in the explicit purge operation/task;
  do not revive expired pages during lookup.
- Public pages, structured data, and seeds contain metadata rather than lyric
  text. The homepage and the printing guide are the only crawlable surfaces; the
  public song catalog was removed, so do not reintroduce song URLs, browse
  pagination, or `Song` publication state without a new decision.
- Songs record sourced demand only. Keep `Song` free of publication state and
  keep the sitemap limited to the homepage and guide.

## External input and integrations

- Keep LRCLIB HTTP behavior in `LrcLibClient`, despite its existing location in
  `app/services/`. Inject clients/connections for tests. Retain finite connect
  and read timeouts, response-shape validation, and distinct not-found and
  temporary-service errors.
- Treat `LrcLibClient::NotFoundError` and `LrcLibClient::ServiceError` as the
  shared source vocabulary: `SongLookup`, `SongSearch`, and `SongCatalogVerifier`
  let them propagate and callers translate them into user copy and HTTP status.
  Do not add a parallel error hierarchy or wrap errors into status symbols inside
  domain objects.
- Use the fixed LRCLIB base URL and validated source IDs. A pasted source URL
  is not authorization to fetch an arbitrary destination.
- Preserve plain-lyrics preference, synced-lyrics timestamp removal,
  instrumental filtering, deduplication, and bounded search results when
  changing source parsing.
- Use parameterized SQL and strong parameters. Keep CSRF protection on browser
  endpoints, escape output, and filter sensitive input from logs. Pass any
  subprocess arguments separately rather than interpolating external input.
- Never send lyric text, real saved-page tokens, or song metadata to analytics.
  Use the existing analytics helper, token-path redaction, allowlisted campaign
  values, and documented event names. Avoid duplicate events on Turbo visits.
  Opening the print dialog does not prove a physical page was printed. Campaign
  values are defined by `AnalyticsCampaigns` and rendered to the client; update
  that object and the operations document together rather than duplicating a
  list in JavaScript.

## Hotwire, styling, and printing

- Prefer server-rendered HTML and Turbo forms; use small Stimulus controllers
  for browser interaction. Keep imports in `config/importmap.rb` and follow
  the existing controller registration instead of adding a bundler.
- Edit Tailwind source in `app/assets/tailwind/application.css`, not generated
  files in `app/assets/builds/`. Keep reusable print behavior in styles and
  the existing preview controller.
- Verify typography, columns, stanza breaks, margins, overflow, and hidden
  controls in both screen preview and browser print preview when changing
  layout. Cover long lyrics and large type; avoid clipping text to make it fit.
- Preserve usable controls when browser storage is unavailable; use
  `SettingsStore` for preview preferences. Clean up listeners and observers
  on Stimulus disconnect and account for Turbo reconnection.
- Follow `PRODUCT.md`: calm, practical UI, semantic labels, keyboard access,
  visible focus, accessible loading/error states, and high-contrast printed
  text independent of the screen theme.

## Database changes

- Generate migrations with `bin/rails generate migration`; use SQLite-compatible
  schema and query behavior. Commit the resulting `db/schema.rb` changes.
- Back important invariants with database constraints and indexes, especially
  token, slug, and source-ID uniqueness. Model validation alone is insufficient
  under concurrent requests.
- Use short transactions with bang writes or explicit failure handling for
  atomic changes. Keep external network calls outside database transactions.
- Keep simple reusable filters in scopes and complex queries in cohesive
  objects. Bound query work and pagination; check for N+1 queries.
- Use `update_column(s)` or `delete_all` only deliberately: they bypass model
  lifecycle behavior. Preserve the distinction between verification timestamps
  and metadata refreshes when changing `Song#promote!`.
- Keep seeds idempotent and metadata-only. Do not overwrite later source
  refreshes or use database reset/replant commands against retained user data.

## Testing and verification

- Use Minitest, following `test/models`, `test/services`, `test/integration`,
  `test/tasks`, and `test/system`. Prefer a failing regression test for behavior
  fixes, then implementation and refactoring. Test outcomes and meaningful
  failure cases rather than private methods or one test per method.
- Test domain rules and workflows directly; use integration tests for HTTP
  status, persistence, Turbo markup, and indexing contracts. Use system tests
  for JavaScript, keyboard interaction, and the search-to-print journey.
- Keep setup local and small; existing tests construct records directly.
  Use unsaved objects when persistence is unnecessary. Do not introduce
  factories or RSpec just to add coverage.
- Stub HTTP at the client boundary. Client tests use Faraday's test adapter;
  higher-level tests inject small fake clients. Do not assume WebMock is
  installed or that the suite globally blocks network access.
- Cover relevant failure paths: malformed or unavailable source data, invalid
  catalog tokens, failed atomic saves, expiration boundaries, and transient
  source failures. Use Rails time helpers for deterministic time tests.
- Run focused tests and Ruby lint for changed behavior. Run system tests for
  browser changes and asset compilation for asset changes; broaden checks for
  shared code. Browser assertions do not replace print-preview inspection.
- Report the actual checks and any unverified behavior. Do not add tests for
  prose edits or assertions that merely restate the implementation.

## Comments and scope

Prefer clear names and focused methods to comments narrating the code. Explain
non-obvious constraints, tradeoffs, or algorithms when that context would
otherwise be lost. Keep refactors tied to the requested change, and update
these guidelines when the project's conventions or contracts change.
