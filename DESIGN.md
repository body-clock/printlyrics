# PrintLyrics design

This file is the entrypoint for anyone changing how PrintLyrics looks: an
engineer, a designer, or an agent. It states the visual intent, the shared
rules, and where each value lives. Product requirements stay in
[PRODUCT.md](PRODUCT.md); component use lives in the contracts under
[`design-system/`](design-system/COMPONENTS.md).

Authority, in order:

1. `PRODUCT.md` for what the product is and who it serves.
2. This file for visual direction and cross-cutting rules.
3. A component, layout, or pattern contract for when and how to use that entity.
4. The token block in
   [app/assets/tailwind/application.css](app/assets/tailwind/application.css)
   for values.

When two sources disagree, treat the disagreement as a defect and record it in
[the gap journal](design-system/gaps.md). Do not silently pick one.

## Intent and shared rules

PrintLyrics turns lyrics into a page someone can read on paper. The sheet is the
north star: the screen exists to produce it, not to compete with it. The visual
character is quiet, literate, and dependable — a serif headline, a warm neutral
canvas, one rust accent, and generous room for the words. It should feel
considered without becoming precious, decorative, or self-conscious.

Required rules:

- **The lyrics and the print result come first.** Product chrome, prompts, and
  navigational flourishes never push the sheet or the form out of the way.
- **Preview and print are one promise.** A change to `.paper` must be checked in
  the browser preview and in the printed or PDF result. Screen-only styling must
  not leak into `@media print`.
- **One navigation surface.** The site header is the only global navigation and
  the footer holds the guides, feedback, retention note, and version. Do not
  repeat global/account menus in page bodies. Contextual prose links to the
  printing guides may support the task without becoming another navigation menu.
- **One system, not page-specific styles.** An element that appears on more than
  one page uses a contract in `design-system/` or the token catalogue. Do not
  copy a block of CSS into a page because it is faster.
- **Calm by default.** No glass effects, gradients used as decoration, oversized
  marketing copy, novelty controls, or colour used only for ornament.

Recommendations:

- Prefer an existing contract and its variants before composing a new pattern.
- Keep status communication readable without colour: pair a status colour with a
  mark, label, or copy.
- Leave whitespace at section boundaries rather than adding rules. A horizontal
  line is a structural decision, not a default separator.

### North-star surfaces

There is no separate Figma or Storybook source. The reference implementation is
the shipped interface, and these four surfaces define the visual bar:

- `/` — entry: compact serif introduction, accessible Find/Paste modes, in-flow
  results, and a lyrics-first review surface with recoverable drafts.
- `/print-lyrics-on-one-page` and `/print-a-songbook` — public guides: a readable
  column, numbered steps, native disclosures, one closing action.
- `/account/new` — account panel: one bordered surface, Google first, email as
  the quiet fallback.
- A generated `/lyrics/:token` — preview: chrome recedes, the paper is the
  subject, and the printed PDF matches the screen sheet.

When a new surface is ambiguous, match the nearest north-star surface rather
than inventing a page-local treatment.

## Design-system sources

- Tokens and themes:
  [app/assets/tailwind/application.css](app/assets/tailwind/application.css).
  The `:root` block is the catalogue; the dark override is the same catalogue
  under `prefers-color-scheme: dark`.
- Components: [index](design-system/COMPONENTS.md).
- Layouts: [index](design-system/LAYOUTS.md).
- Patterns: [index](design-system/PATTERNS.md).
- Product intent: [PRODUCT.md](PRODUCT.md).
- Migration map and adoption rules:
  [design-system/MIGRATION.md](design-system/MIGRATION.md).
- Live checks: the routes in [Verification](#verification).

There is no Storybook and no icon package. The contracts name the ERB partials,
CSS classes, and Stimulus controllers that implement each entity.

## Foundations

### Colour

Four groups, each with one job. A colour belongs to exactly one group; if a new
need does not fit a group, it is a gap, not a new token by improvisation.

| Group | Tokens | Job | Constraint |
| --- | --- | --- | --- |
| Elevation | `--elevation-canvas`, `--elevation-surface`, `--elevation-sunken`, `--elevation-preview`, `--elevation-shadow-card`, `--elevation-shadow-panel`, `--elevation-shadow-notice` | The page, raised panels, recessed fills, the preview stage, and the three shadow depths. | Never use an elevation token as text or as an interactive accent. |
| Content | `--content-primary`, `--content-secondary`, `--content-placeholder`, `--content-on-accent` | Text and glyphs: primary copy, secondary/meta copy, input placeholders, and text on an accent fill. | Text on a surface must meet 4.5:1. `--content-secondary` is the lightest text allowed for body-sized copy. |
| UI | `--ui-accent`, `--ui-accent-hover`, `--ui-focus`, `--ui-primary`, `--ui-on-primary`, `--ui-success`, `--ui-success-surface`, `--ui-danger`, `--ui-danger-surface` | Interactive identity, focus rings, the primary action fill, and success/danger status pairs. | `--ui-accent` is the only brand accent. Never use accent for a passing state; success has its own green. |
| Border | `--border-default`, `--border-control`, `--border-control-hover`, `--border-strong`, `--border-accent`, `--border-success`, `--border-danger` | Rules between content, control edges, emphasised panel edges, and tinted status edges. | `--border-default` is decorative and must not be the only boundary of a form control. Use `--border-control` there. |

Colours are written in OKLCH. This is the rule that lets an agent extend the
palette without guessing: hold the hue and lightness, step the chroma, and the
new shade already belongs to the family. Do not add a hex value, an `rgb()`, or
a one-off `oklch()` outside the token block. A shade that a component needs but
the shared catalogue does not have is a gap.

Contrast evidence for the shipped values (WCAG 2.x relative luminance; 4.5:1 for
text, 3:1 for non-text indicators):

| Pair | Light | Dark | Minimum |
| --- | --- | --- | --- |
| `content-primary` on `elevation-canvas` | 14.47 | 14.27 | 4.5 |
| `content-primary` on `elevation-surface` | 15.66 | 12.78 | 4.5 |
| `content-secondary` on `elevation-canvas` | 5.92 | 6.78 | 4.5 |
| `content-secondary` on `elevation-surface` | 6.40 | 6.07 | 4.5 |
| `content-placeholder` on `elevation-surface` | 6.40 | 6.07 | 4.5 |
| `ui-accent` on `elevation-canvas` | 6.29 | 6.42 | 4.5 |
| `content-on-accent` on `ui-accent` | 6.57 | 6.67 | 4.5 |
| `ui-success` on `ui-success-surface` | 5.42 | 7.99 | 4.5 |
| `ui-danger` on `ui-danger-surface` | 5.44 | 7.76 | 4.5 |
| `ui-focus` against `elevation-canvas` | 3.33 | 7.49 | 3 |
| `border-control` against `elevation-canvas` | 3.29 | 3.75 | 3 |

Rules:

- Use semantic tokens only. Never write a raw colour in a component.
- Placeholder text uses the opaque secondary tone through its semantic role;
  reducing its opacity can fail text contrast even when labels remain visible.
- Use `--border-default` for separators and `--border-control` for anything a
  visitor must perceive as an input edge. The default border is intentionally
  quiet and does not meet non-text contrast.
- The focus ring is always opaque `3px var(--ui-focus)` with `2px` offset. A
  translucent ring can fall below 3:1.
- Dark mode is automatic. Do not add a `.dark` class or a second colour set.
- The layout's `theme-color` meta mirrors `--elevation-canvas`. Update both
  values together.
- Print uses `--print-paper`, `--print-ink`, `--print-muted`, and
  `--print-rule`. Screen elevation and status colours never reach paper.

### Typography

Families:

- `--font-sans`: the system UI stack. Controls, body copy, labels, and meta.
- `--font-serif`: Georgia with a Times fallback. Page titles, brand, lyric
  titles, and the lyric body on paper.

Six sizes and four weights. Every size has one job; a new size is not a design
decision, it is a system defect.

| Token | Size | Job | Do not |
| --- | --- | --- | --- |
| `--text-display` | `clamp(2rem, 5vw, 2.75rem)` | The `h1` of a page: entry, guide, account, library. | Use for section headings or marketing copy inside a page. |
| `--text-heading` | `1.5rem` | A section `h2` that opens a distinct block: explainer, FAQ, empty state. | Use for card titles or dense form sections. |
| `--text-title` | `1.25rem` | A card, step, or answer title; the brand wordmark. | Use for an action label. |
| `--text-body` | `1rem` | Running prose, all text inputs and textareas. | Shrink input text below 16px on phones. |
| `--text-label` | `0.9375rem` | Interactive labels, field labels, buttons, list actions, prompt titles. | Use for long reading passages. |
| `--text-meta` | `0.8125rem` | Eyebrows, timestamps, counts, footer and helper text. | Use for body copy or a primary action. |

Weights: `--weight-regular: 400` (prose), `--weight-medium: 500` (serif display
and titles), `--weight-semibold: 600` (printed lyric title, selected track),
`--weight-bold: 700` (labels, eyebrows, actions). No 650/750/800 intermediates.

Leading: `--leading-display: 1.08` for display serif, `--leading-heading: 1.2`
for card titles, `--leading-body: 1.5` for prose, `--leading-label: 1.35` for
multi-line labels, `--leading-compact: 1` for single-line buttons and icons.

Tracking: `--tracking-brand: 0.01em`, `--tracking-eyebrow: 0.09em`,
`--tracking-divider: 0.08em`. Uppercase meta text carries one of the two
uppercase trackings.

Rules:

- A button label uses `--text-label`. There is no second button size.
- Sentence case for labels and headings; uppercase only for eyebrow/divider
  meta text with its tracking token.
- Do not load a web font. The system stack is deliberate: it keeps the product
  fast and the print preview honest.

### Spacing

A 4px scale for padding, margin, and gap:

| Token | rem | px | Use for |
| --- | --- | --- | --- |
| `--space-0-5` | 0.125 | 2 | Hairline nudges: result title/subtitle, meter dots. |
| `--space-1` | 0.25 | 4 | Tight inline gaps, icon-to-label. |
| `--space-1-5` | 0.375 | 6 | Compact rows and small control padding. |
| `--space-2` | 0.5 | 8 | Default inline gap, compact padding. |
| `--space-3` | 0.75 | 12 | Control padding, card internals, paragraph gaps. |
| `--space-4` | 1 | 16 | Default component gap, form grid gap. |
| `--space-5` | 1.25 | 20 | Panel and card padding. |
| `--space-6` | 1.5 | 24 | Panel padding, section internals. |
| `--space-8` | 2 | 32 | Section separation, generous panel padding. |
| `--space-10` | 2.5 | 40 | Page-shell top padding on reading pages. |
| `--space-12` | 3 | 48 | Entry/account top padding, guide-step indent. |
| `--space-14` | 3.5 | 56 | Separation before a major page footer block. |

Rules:

- Padding, margin, and gap use the scale. Do not introduce a new spacing value.
- Control heights, widths, fixed offsets, and physical print measurements are
  component dimensions, not spacing. Use `--control-*`, `--layout-*`, or the
  print tokens; keep a local value only when it is genuinely geometric.
- Vertical rhythm is owned by the layout or pattern, not by the child component.
  A component does not add outer margins to position itself.

### Radius

| Token | Value | Job |
| --- | --- | --- |
| `--radius-xs` | 2px | Meter dots and hairline marks. |
| `--radius-sm` | 4px | Controls: buttons, inputs, small panels, icon buttons. |
| `--radius-md` | 6px | Surfaces: cards, panels, callouts, prompts, track lists. |
| `--radius-full` | 50% | Spinners and circular marks. |

There are no 3px or 8px radii. A radius either belongs to a control, a surface, a
dot, or a circle.

### Elevation

| Token | Job |
| --- | --- |
| `--elevation-canvas` | The page background. One per page. |
| `--elevation-surface` | A raised panel, card, toolbar, or control fill. |
| `--elevation-sunken` | A recessed fill: hover, selected segment, miss panel. |
| `--elevation-preview` | The neutral stage behind the paper. |
| `--elevation-shadow-card` | The printed sheet resting on the stage. |
| `--elevation-shadow-panel` | The floating search-results panel. |
| `--elevation-shadow-notice` | The fixed flash notice. |

Shadows communicate layering; they are not decoration. Only the three named
shadows exist. Do not invent a fourth.

### Icons

- No icon library. Icons are inline SVG (the sheet mark) or single text glyphs
  (`←`, `+`, `↗`, `×`, `✓`, `!`, `G`).
- A decorative glyph or SVG carries `aria-hidden="true"`. A control whose only
  content is an icon carries an accessible name (`aria-label` or visible text).
- Glyph size follows the text it accompanies, or `--icon-md` for a standalone
  icon control. Icon-only controls use `--control-icon` as their box.
- Do not add a dependency for an icon that a glyph or a 24px path can express.
- The sheet mark is physical: it is sized in inches and printed. Do not restyle
  it as a screen icon.

### Motion

- One transition duration: `--motion-fast` (160ms) with `ease-out`, and only for
  colour, border, or background.
- A native disclosure and the mobile format panel may fade their revealed
  content in over `--motion-fast`. Height, position, and the paper never animate,
  and nothing else enters with motion.
- The search spinner uses `--motion-spin` (700ms, linear).
- Respect `prefers-reduced-motion: reduce`; it is handled globally.
- Do not animate layout, position, or the paper. No other entrance animations.

### Print

The sheet is letter paper: `--sheet-width: 8.5in`, `--sheet-height: 11in`,
`--sheet-margin: 0.75in`. The paper background is `--print-paper`, its text is
`--print-ink`, and its secondary text and rules are `--print-muted` and
`--print-rule`.

Rules:

- A printed sheet always uses paper white and print ink, independent of the
  screen theme. `@media print` resets the page background.
- Lyric sizes are component tokens on `.paper` (`--lyric-body-size`,
  `--lyric-title-size`, `--lyric-artist-size`, `--lyric-line-height`,
  `--stanza-gap`) and are expressed in `pt` or `em`. The size variants
  (`size-s`, `size-m`, `size-l`, `size-xl`) are the only supported sizes.
- Screen chrome carries `no-print`; the paper does not.
- A change to preview typography must be checked against the PDF/print result.

## Layout and adaptation

| Token | Width | Surface |
| --- | --- | --- |
| `--layout-landing` | `45rem` | Find/Paste entry and review |
| `--layout-reading` | `46rem` | Guides and account pages |
| `--layout-library` | `60rem` | Saved-items list |
| `--layout-wide` | `62rem` | Site header and footer |
| `--layout-toolbar` | `88rem` | Workspace and action band |
| `--layout-inspector` | `17.5rem` | Inline format inspector |
| `--layout-outline` | `14.5rem` | Wide song outline |
| `--measure-prose` | `39rem` | Long-form copy inside a shell |
| `--measure-panel` | `32rem` | Account panels and forms |

- Breakpoints follow content: metadata pairs collapse below 560px; supporting
  prose arrangements below 700px; the format inspector becomes inline at
  1100px; a persistent third-column song outline requires 1440px.
- The header keeps one compact control row across normal pages. Every header
  item occupies `--control-touch`; account creation belongs in the account flow,
  not a competing homepage action.
- Standalone working controls, disclosure summaries and secondary actions target
  at least 44px (`--control-touch`); primary inputs/actions use 48px
  (`--control-lg`). Never shrink controls on phones.
- No page may scroll horizontally at 320px. The paper is wider than a phone by
  design; Fit scales it to the stage through `--preview-scale`. Explicit zoom
  scrolls only within the document stage, independently of printed type size.
- Print output is letter, `@page { size: letter; margin: 0; }`.

## Components, layouts and patterns

- [Components](design-system/COMPONENTS.md): button, field, flash, form errors,
  segmented control, inline offer, library card, paper sheet, site header.
- [Layouts](design-system/LAYOUTS.md): site shell, account shell, guide shell,
  preview shell.
- [Patterns](design-system/PATTERNS.md): lyric entry, print preview, account
  access, saved library.

The [workspace interaction specification](docs/plans/2026-10-26-002-mobile-workspace-interaction.md)
defines draft lifetime, immutable revisions, navigation, failure recovery and
phone/wide reference compositions. Revisions create independent sheets; they do
not silently replace library items or songbook entries.

Contract statuses follow the shared model:

- `discoverable` — implemented and eligible for new work.
- `hidden` — managed but not available for new selection.
- `deprecated` — excluded from new work; preserve existing calls until migrated.

A UI element with no contract is `unmanaged`. You may inspect its code as a
fallback after the managed indexes show no fit, but you must report that the
choice is unmanaged. Do not invent a contract for it unless you are doing
design-system work.

## Agent rules

Before writing UI code:

1. Read this file and the relevant contract.
2. Search the indexes for an existing component, layout, or pattern that solves
   the request. Reuse it before composing a new variant.
3. Use the documented classes and partials. Do not restyle a component from the
   caller with one-off CSS or utility classes.
4. If the request needs a value the system does not have, use the nearest
   existing role and record the gap. Do not add a colour, size, radius, shadow,
   or spacing value in the page.

Never:

- Add a raw colour, font size, font weight, radius, or shadow outside the token
  block.
- Add a second button height or a second primary-action colour.
- Use an elevation token as text, or a content token as a large fill.
- Make a printed surface depend on the screen theme.
- Change a shared class for one page's local need.
- Edit `design-system/COMPONENTS.md`, `LAYOUTS.md`, or `PATTERNS.md` by hand;
  they are generated from contracts.

When a contract and the implementation disagree, the implementation is evidence
of a defect, not permission to rewrite the promise. Record the gap and fix the
implementation in design-system work.

## Verification

Run the checks that cover the change:

```sh
bin/rails tailwindcss:build          # token/CSS syntax and asset build
bin/rails test                       # application behaviour
bin/rails test:system                # browser and print surfaces
bin/rails assets:precompile          # production asset path
```

Browser surfaces worth checking after a visual change, at 390px and 1280px, in
light and dark mode:

- `/` — Find/Paste, review, recovered/invalid drafts and failed search.
- `/print-lyrics-on-one-page` and `/print-a-songbook` — guide shell and prose.
- `/session/new` — account shell, panel, fields, Google button.
- A generated `/lyrics/:token` — document stage, inspector, zoom, edit/revision,
  measured page counts and PDF at every size/column combination.
- A mixed-format `/songbooks/:token` — outline, current song, scoped/bulk changes,
  save-failure retry and continuation pages.

Contract checks:

```sh
node design-system/scripts/generate-indexes.mjs --check .
node design-system/scripts/check-contract.mjs --kind component \
  --inventory design-system/COMPONENTS.md \
  --inventory design-system/LAYOUTS.md \
  --inventory design-system/PATTERNS.md \
  design-system/components/*.md
```

Run the matching command for `layouts` and `patterns`. After reviewing a
contract whose sources changed, regenerate its source snapshot with
`--update-sources-hash`. These scripts need Node; they are documentation checks
and are not part of the asset pipeline.

Contrast values in this file were computed from the OKLCH token values using the
WCAG 2.x relative-luminance formula. If a palette token changes, recompute the
affected rows and update this table in the same change.

## Migration

The system replaced the original ad-hoc palette, type sizes, and radii without a
transitional alias layer. The old-to-new map, the intentional visual changes,
and the rules for touching an unmigrated value are in
[design-system/MIGRATION.md](design-system/MIGRATION.md).

## Gaps and decisions

Open gaps: [journal](design-system/gaps.md). Closed entries:
[archive](design-system/gaps-archive.md).

Independent quality gates are not a project requirement. Verification follows
the repository's commands above and the task's explicit scope.
