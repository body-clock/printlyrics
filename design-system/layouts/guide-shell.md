---
sourcesHash: 6520d2cc85de0ba25b64c412e09780a40f14047ecc3b0335a83db9bcbe42603e
id: guide-shell
description: >-
  Lay out a public long-form printing guide as one readable article with a
  short answer, numbered steps, an FAQ, and a closing callout.
status: discoverable
sources:
  - app/assets/tailwind/application.css
  - app/views/printing_guides/one_page.html.erb
  - app/views/printing_guides/songbook.html.erb
tests:
  - test/integration/printing_guides_test.rb
---

# Guide shell

## When to use

- The two indexable printing guides: printing lyrics on one page, and printing
  a songbook.
- A future public explainer that has the same shape: question, short answer,
  procedure, questions, tool callout.

## When not to use

- The homepage's explainer and FAQ, which live inside the entry page below the
  form and use the landing shell.
- Account pages, the library, or the print preview.
- A marketing landing page. The product's anti-references rule out that shape.

## Public API

```erb
<div class="guide-shell">
  <article class="guide">
    <header>
      <p class="eyebrow">...</p>
      <h1>...</h1>
      <p>...</p>
    </header>

    <section class="guide-answer">...</section>
    <ol class="guide-steps">...</ol>
    <section class="faq guide-faq">...</section>
    <section class="guide-callout">...</section>
  </article>
</div>
```

- `.guide-shell` is `--layout-reading` wide with the reading-page top padding.
- `article.guide` is the single content column.
- `.guide header` owns the eyebrow, `h1`, intro, and the bottom rule.
- `.guide-answer` is the highlighted short answer with an accent left edge.
- `.guide-steps` is an ordered list; each item uses a counter in
  `--text-meta` and a bottom rule.
- `.faq` uses native `<details>`/`<summary>`; `.guide-faq` only adds spacing.
- `.guide-callout` closes the article with a heading, body, and one primary
  action.

## Composition

- The article has exactly one `h1`, then `h2` for the answer, steps, FAQ, and
  callout. Do not skip a level for visual size.
- The header's structured data is built from the same locale keys as the visible
  steps. When copy changes, both the visible and structured versions change.
- The answer section is optional only when the guide has no single sentence
  answer; the steps and FAQ are required for a complete guide.
- The callout contains one action and one paragraph. Do not stack two competing
  primary actions.
- Section spacing is the article's: `--space-10` before the FAQ and callout.
  Child sections do not add their own outer width or page padding.
- Below `700px` the shell uses the same width rule as every other page; the
  steps keep their numbered indent.

## Accessibility

- The reading order is header, answer, steps, FAQ, callout. Do not use CSS
  order to rearrange the article.
- `<details>`/`<summary>` provides the FAQ disclosure behaviour and keyboard
  support natively; do not replace it with a custom accordion.
- The answer's accent left edge is decoration. The heading and text carry the
  meaning.
- The callout action is a link to the tool with a visible label; it is not an
  icon-only control.
- Long prose is bounded by `--measure-prose` for readability.
