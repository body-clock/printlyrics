# PrintLyrics agent guide

Keep this file short. It records repository-specific constraints that are easy
to miss; discover implementation details from the code and follow nearby
patterns rather than expanding this into a directory tour or style guide.

## Product contract

PrintLyrics is a focused tool for finding or pasting lyrics and producing a
clean, shareable, print-optimized sheet. Preserve the short search/edit/preview/
print flow. The lyric sheet and fidelity between preview and paper take priority
over marketing or application chrome.

Read `PRODUCT.md` before changing user-facing behavior or design. Keep the UI
quiet, plain, accessible to WCAG 2.2 AA, keyboard usable, reduced-motion safe,
and legible when printed without screen color or theme.

## Application shape

- Rails 8.1, Ruby 4.0, SQLite, Hotwire, import maps, Tailwind, and a small amount
  of Stimulus. Do not introduce Node or a client-side framework without an
  explicit architectural reason.
- Prefer Rails conventions and RESTful resources. Keep controllers concerned
  with HTTP/session orchestration, domain behavior in models or focused plain
  Ruby objects, and presentation in helpers/views.
- Prefer server-rendered HTML and Turbo. Use Stimulus only for browser behavior;
  core flows must not depend on JavaScript where a Rails response suffices.
- Preserve the deployment model: one Kamal web container and SQLite on its
  persistent volume. Schema changes require migrations; never hand-edit
  `db/schema.rb`.

## Non-negotiable invariants

- LRCLIB is an external, fallible boundary. Keep timeouts, the identifying user
  agent, response validation, and distinct not-found versus transient-failure
  behavior. Tests must not require the live service.
- Selecting an LRCLIB result only fills the editable form. Persist lyrics only
  when the user generates a page. Trust catalog metadata only through the
  short-lived signed token flow.
- Manually entered lyrics must not create catalog songs. Public song pages store
  metadata only; do not expose or index saved lyric pages.
- Saved lyric URLs use unguessable tokens. Lyrics expire 180 days after their
  last visit. Retention renewal and expired-record cleanup must remain intact.
- A non-curated song becomes indexable only after three successful sourced page
  generations. A confirmed LRCLIB 404 marks it unavailable; transient failures
  must preserve its last known public state.
- Never send lyrics, titles, artists, albums, source IDs, lyric tokens, search
  text, or arbitrary query values to analytics. Saved lyric pageviews must use
  `/lyrics/:token`; analytics dimensions remain low-cardinality and allowlisted.
- Keep saved lyric URLs out of sitemaps and search indexes. Changes to public
  discovery, catalog verification, analytics, or launch measurement must also
  account for `docs/organic-search-operations.md`.

## Verification

Add the narrowest test that proves behavior, plus a regression test for a bug.
Use model/service tests for domain and LRCLIB behavior, integration tests for
request flows and status codes, and system tests only for browser interactions
such as preview, printing, or analytics wiring. Prefer fixtures and injected
boundary fakes over broad mocking.

Run the checks relevant to the change; run the full gate before handing off a
substantial change:

```sh
bin/ci
```

Individual checks are documented in `README.md`. When changing print UI, inspect
both screen and print presentation in a real browser. When changing migrations,
verify both migration and a fresh schema load.

## Delivery

Keep commits focused and use Conventional Commit subjects (`feat:`, `fix:`,
`docs:`, `test:`, `refactor:`, `chore:`). Release Please derives releases and
`CHANGELOG.md` updates from commits after merge; do not manually edit release
artifacts for ordinary changes.

Do not place secrets in the repository. Deployment requirements live in
`README.md`; organic-search rollout, recurring verification, monitoring, and
rollback procedures live in `docs/organic-search-operations.md`.
