# Design-system migration

This records the move from the original ad-hoc styles to the token system in
[`app/assets/tailwind/application.css`](../app/assets/tailwind/application.css).
It is history and a rule book for touching an unmigrated value; the current
promise is [DESIGN.md](../DESIGN.md).

## What was there

An audit of the single stylesheet before the migration:

- 2,090 lines and 252 rule blocks.
- 16 light-theme custom properties and 15 dark overrides, plus seven raw
  `oklch()` values outside the token block.
- 27 `font-size` declarations covering 14 distinct rem sizes (0.68–2.25rem),
  two `clamp()` values, four print `pt` sizes, and three lyric variables.
- Seven font weights: 400, 500, 600, 650, 700, 750, 800.
- Five radii: 2px, 3px, 4px, 6px, 50%.
- More than 80 distinct rem spacing values in padding, margin, and gap, including
  0.12, 0.28, 0.35, 0.45, 0.55, 0.65, 0.85, 1.05, 1.15, 1.35, 1.75, and 1.85.

The migration did not change the visual identity. It removed arbitrary choices
inside that identity.

## Transitional aliases

There are none. Every consumer was migrated in the same change, so an alias such
as `--ink` would be dead weight and would let new code keep using the old
vocabulary. When reading an older commit or an old screenshot, use the map below.

## Colour map

| Old | New | Group |
| --- | --- | --- |
| `--canvas` | `--elevation-canvas` | Elevation |
| `--surface` | `--elevation-surface` | Elevation |
| `--surface-muted` | `--elevation-sunken` | Elevation |
| `--paper` | `--print-paper` | Print (the old token was unused) |
| `--ink` | `--content-primary` | Content |
| `--ink-muted` | `--content-secondary` | Content |
| `--accent-ink` | `--content-on-accent` | Content |
| `--accent` | `--ui-accent` | UI |
| `--accent-hover` | `--ui-accent-hover` | UI |
| `--focus` | `--ui-focus` | UI |
| `--success` | `--ui-success` | UI |
| `--success-bg` | `--ui-success-surface` | UI |
| `--error` | `--ui-danger` | UI |
| `--error-bg` | `--ui-danger-surface` | UI |
| `--line` | `--border-default` | Border |
| `--shadow` | `--elevation-shadow-card` | Elevation |

New tokens with no predecessor:

- `--elevation-preview` — the preview stage, previously a raw light/dark value.
- `--content-placeholder` — the input placeholder mix.
- `--ui-primary`, `--ui-on-primary` — the filled primary action expressed as a
  role rather than borrowed from `ink`/`surface` at the call site.
- `--border-control`, `--border-control-hover` — the input edge. The old
  `--line` was 1.6:1 against a surface, below the 3:1 non-text minimum; the new
  control border is 3.56:1 light and 3.35:1 dark.
- `--border-strong` — the floating search panel edge.
- `--border-accent`, `--border-success`, `--border-danger` — the tinted status
  and accent edges that were `color-mix()` expressions inside rules.
- `--elevation-shadow-panel`, `--elevation-shadow-notice` — the two raw shadows.

## Type map

| Old size | New token | Note |
| --- | --- | --- |
| 2.25rem, `clamp(2rem, 6vw, 3rem)`, `clamp(2rem, 5vw, 2.8rem)` | `--text-display` | One fluid page title. |
| 1.5rem | `--text-heading` | Section `h2`. |
| 1.25rem, 1.15rem, 1.12rem | `--text-title` | Card/step/answer title and brand. |
| 1rem | `--text-body` | Prose. |
| 0.86, 0.85, 0.84, 0.82, 0.78 | `--text-label` | One interactive and label size. |
| 0.8, 0.76, 0.75, 0.74, 0.72, 0.7, 0.68 | `--text-meta` | One meta and caption size. |

Weights: 650 → 600; 750 and 800 → 700. 400, 500, and 700 are unchanged; 600 is
now the only semibold.

Intentional visual differences:

- Page titles are fluid and share one maximum (2.75rem). The entry page title was
  fixed at 2.25rem, the guide at up to 3rem, and the account title at up to
  2.8rem.
- Small text moved onto two steps. Most 0.68–0.74rem meta grew to 0.75rem;
  0.78rem explanatory copy grew to 0.85rem; 0.86rem labels settled at 0.85rem.
- The brand wordmark grew from 1.12rem to 1.25rem.
- The printed lyric title leading moved from 1.1 to the display leading (1.08).
- The search-results close box grew from 2rem to `--control-icon` (2.15rem) so
  square icon controls share one size.
- The songbook offer's accent edge moved from a 70% accent mix to the shared
  `--border-accent` (60%), so accent-tinted edges have one answer.

## Radius map

| Old | New |
| --- | --- |
| 2px | `--radius-xs` |
| 3px, 4px | `--radius-sm` |
| 6px | `--radius-md` |
| 50% | `--radius-full` |

The 3px segmented-control and track-remove corners became 4px so a control edge
has one answer.

## Spacing map

Spacing moved to the 4px scale in DESIGN.md. The general rule was nearest step,
with a preference for the tighter step at a tie:

| Old range | Token |
| --- | --- |
| 0.12 | `--space-0-5` |
| 0.2–0.3 | `--space-1` |
| 0.35–0.4 | `--space-1-5` |
| 0.45–0.6 | `--space-2` |
| 0.65–0.85 | `--space-3` |
| 0.9–1.1 | `--space-4` |
| 1.15–1.35 | `--space-5` |
| 1.5 | `--space-6` |
| 1.75–2 | `--space-8` |
| 2.5 | `--space-10` |
| 2.75–3 | `--space-12` |
| 3.5 | `--space-14` |

The largest movement is the page-shell top padding (2.75rem → 3rem) and the
guide-step padding (1.75rem → 2rem). Both are under 4px and were checked in the
browser.

Physical print measurements are not spacing and did not move: sheet size,
margins, lyric sizes, stanza gaps, and the sheet mark are expressed in `in`,
`pt`, or `em`.

## Control and layout dimensions

Repeated heights and widths became tokens:

- `--control-lg: 3rem` — form controls and the primary button.
- `--control-md: 2.55rem` — toolbar actions.
- `--control-sm: 2.35rem` — compact prompt actions.
- `--control-xs: 2.1rem` — header items.
- `--control-touch: 2.75rem` — the minimum primary touch target.
- `--control-icon: 2.15rem` — square icon controls.
- `--icon-md: 1.25rem` — a standalone icon glyph.
- `--layout-landing`, `--layout-reading`, `--layout-library`,
  `--layout-wide`, `--layout-toolbar`, `--measure-prose`, `--measure-panel`.

The floating search panel is positioned with `--space-*`; its `7.2rem` submit
width remains a component dimension because it matches the search button.

## Consumer changes

Two quiet text actions collapsed into one class:

| Old class | New class | Where |
| --- | --- | --- |
| `.library-remove` | `.button-text .button-text-danger` | `app/views/saved_items/index.html.erb` |
| `.account-prompt-dismiss` | `.button-text` | `app/views/shared/_account_prompt.html.erb` |

The library's remove button keeps its danger hover through the modifier. The
`.button-text` base is the contract's tertiary action, documented under Button.

## Removed weight

- `--paper` was defined in both themes and never used; the sheet hard-coded
  white. Removed in favour of `--print-paper`.
- `--shadow` became `--elevation-shadow-card`.
- The 2% transparent control-bar mix became a solid `--elevation-surface`; the
  transparency was invisible and blocked a token value.
- Duplicated `border-radius`, shadow, and colour-mix declarations inside rules
  were replaced by tokens.

## Result

After the migration the stylesheet has:

- 6 type sizes and 4 weights;
- 4 radii;
- 12 spacing steps, all consumed;
- 4 colour groups with light and dark values;
- no raw colour, font size, weight, radius, or shadow outside the token block,
  except the 7pt print mark label and the two `in`/`pt`-based print dimensions
  that are not tokens.

Every token in the catalogue has at least one consumer.

## Touching an unmigrated value

If a rule still contains a value outside the catalogue, or a new request needs a
value the catalogue does not have:

1. Search this map and the token catalogue for an existing role.
2. Use the nearest role rather than introducing a second convention.
3. If the difference is visible and intentional, record a gap in
   [gaps.md](gaps.md) with the affected surface and reason.
4. Add a token only as design-system work: update the catalogue,
   DESIGN.md's role table and, when contrast is affected, the evidence table.

Do not add a page-local colour, size, or spacing value to avoid touching the
system. That is how the original drift started.
