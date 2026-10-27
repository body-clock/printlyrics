---
sourcesHash: 4e3e43e06cab2e0ea7112bcffd54fff7a7bc2d1e92c148e0128d976bfd2d9630
id: site-shell
description: >-
  Frame a normal page with a skip link, the global site header and footer, one
  main landmark, and the shared landing content width.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/layouts/application.html.erb
  - app/views/lyrics/new.html.erb
  - app/views/feedbacks/new.html.erb
tests:
  - test/system/accounts_test.rb
  - test/integration/lyrics_flow_test.rb
---

# Site shell

## When to use

- Any page that keeps the site header and footer: entry, feedback, account
  pages, guides, and the library.
- The shell is the default; a page opts out only when it owns the whole
  viewport.

## When not to use

- Print previews and songbooks. They set `content_for :hide_site_chrome` and use
  [Preview shell](preview-shell.md).
- Mailers and the PWA service worker.
- A page that needs a second global navigation surface. The site has one.

## Public API

The layout supplies:

- the document head and metadata;
- `.skip-link` as the first focusable element;
- `shared/site_header`;
- `<main id="main">` containing `yield`;
- `shared/site_footer`;
- body data attributes and hidden analytics markers owned by the application.

The page supplies:

- `content_for :title`, `:description`, `:canonical_url`, `:robots`,
  `:og_type`, and `:head`;
- `content_for :body_class` for a page-level modifier;
- `content_for :hide_site_chrome` only for immersive pages;
- its own first heading and page content.

`.landing-shell` owns entry width (`--layout-landing`) and top padding, with
`.entry-panel` inside it. Feedback and account forms use account-shell with a
single form panel; guides use guide-shell and the readable measure.

## Composition

- The header and footer are required for every page that does not hide chrome.
  Do not duplicate navigation menus inside the page; contextual prose links may
  explain a related printing step.
- `<main>` is the only main landmark. A page does not add another `<main>`.
- The page's `h1` is the first heading inside the main content. The shell does
  not supply a visible title.
- The shell owns the page-level vertical position. A page block does not add
  top margin to push itself below the header.
- The entry page puts its flash inside its Turbo frame; other pages render
  `shared/flash` near the top of their content. The notice stays inside
  `<main>`.
- Wide structural rules (`border-top`) are section decisions: the explainer,
  FAQ, and footer each own one. Do not add a rule between every block.
- Below `700px` the shell's column is `100% - 2rem`; the page must not introduce
  a fixed width that overflows at 320px.

## Accessibility

- The skip link points to `#main` and becomes visible on focus. It is the first
  tab stop.
- The header and footer are the only `banner`/`contentinfo` landmarks;
  the page does not duplicate them.
- Every page has exactly one `h1`. Section headings follow in order.
- The layout does not move focus on load except where a flow explicitly does.
  Turbo navigation keeps the visitor's position unless the page owns the
  change.
