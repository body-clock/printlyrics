# Design-system gaps archive

Closed entries, preserved in full. Open entries live in
[gaps.md](gaps.md).

## G4 — Form control borders failed non-text contrast

- **Status:** Resolved
- **Opened:** 2026-10-23
- **Closed:** 2026-10-23
- **Source:** `.field input`, `.field select`, `.field textarea` in
  `app/assets/tailwind/application.css`.
- **Actual:** The only border token was `--line` (`oklch(0.84 0.012 78)` light,
  `oklch(0.38 0.012 165)` dark). Against an input surface it measured 1.60:1
  light and 1.63:1 dark, below the 3:1 WCAG 2.2 non-text minimum for a control
  boundary.
- **Expected:** An input edge the visitor can perceive against its surface in
  both themes, without darkening every decorative rule.
- **Resolution:** Added `--border-control` (light `oklch(0.62 0.012 78)`,
  dark `oklch(0.55 0.012 165)`) and used it only for form controls. Kept
  `--border-default` for separators. Hover uses `--border-control-hover`.
- **Verified by:** Computed contrast against `--elevation-surface`: 3.56:1 light
  and 3.35:1 dark; against the canvas 3.29:1 and 3.75:1. Browser inspection of
  `/session/new` confirmed the border colour in both themes.

## G5 — The focus ring fell below 3:1 and was translucent

- **Status:** Resolved
- **Opened:** 2026-10-23
- **Closed:** 2026-10-23
- **Source:** `button:focus-visible`, `a:focus-visible`, `input:focus-visible`,
  `textarea:focus-visible` in `app/assets/tailwind/application.css`.
- **Actual:** The ring was `3px` of `color-mix(--focus, transparent 20%)`; the
  base colour measured 2.98:1 against the light canvas, and mixing it with
  transparency lowered it further.
- **Expected:** An opaque ring of at least 3:1 against the adjacent surface in
  both themes.
- **Resolution:** Made the ring opaque and moved the light base to
  `oklch(0.6 0.15 230)`; the dark base is `oklch(0.72 0.14 230)`.
- **Verified by:** Contrast against `--elevation-canvas` is 3.33:1 light and
  7.49:1 dark; against the surface 3.61:1 and 6.71:1.

## G6 — Type, weight, radius, and spacing drift

- **Status:** Resolved
- **Opened:** 2026-10-23
- **Closed:** 2026-10-23
- **Source:** `app/assets/tailwind/application.css` before the token migration.
- **Actual:** 14 distinct rem font sizes, seven weights, five radii, and more
  than 80 distinct spacing values across 252 rule blocks.
- **Expected:** One obvious choice for each decision: six type sizes, four
  weights, four radii, and a 4px spacing scale.
- **Resolution:** Introduced the token catalogue in DESIGN.md and migrated every
  declaration in the stylesheet. The old-to-new map and intentional visual
  changes are recorded in [MIGRATION.md](MIGRATION.md).
- **Verified by:** The stylesheet now has no raw `font-size` (except the 7pt
  print mark label), no raw weight, no raw radius, and no spacing literal except
  the `-1px` screen-reader offset and physical print measurements. Tailwind
  builds; system tests exercise the preview and account flows.

## G7 — Dead `--paper` token and an unused transparency

- **Status:** Resolved
- **Opened:** 2026-10-23
- **Closed:** 2026-10-23
- **Source:** `:root` and `.control-bar` in
  `app/assets/tailwind/application.css`.
- **Actual:** `--paper` was defined in both themes and never used; the sheet
  hard-coded white. The control bar used
  `color-mix(--surface, transparent 2%)`, which was visually solid but prevented
  a single token value.
- **Expected:** Every token has a consumer, and a surface uses one value.
- **Resolution:** Removed `--paper`; print uses `--print-paper`. The control bar
  uses `--elevation-surface`.
- **Verified by:** `--paper` has no references; grep and the Tailwind build
  confirm the removed token and the solid surface.

## G8 — The theme-color meta did not match the canvas

- **Status:** Resolved
- **Opened:** 2026-10-23
- **Closed:** 2026-10-23
- **Source:** `app/views/layouts/application.html.erb`.
- **Actual:** The browser chrome colours were `#f4f0e8` and `#1d1d1b`; the
  canvas resolved to `#f6f3ed` and `#121715`.
- **Expected:** The installed-app and browser chrome colour matches the page
  canvas in both themes.
- **Resolution:** Updated both meta values and added a comment pointing at
  `--elevation-canvas`.
- **Verified by:** Recomputed the OKLCH canvas to hex: light `#f6f3ed`, dark
  `#121715`; the layout contains those values.

## G9 — Quiet text actions were duplicated three times

- **Status:** Resolved
- **Opened:** 2026-10-23
- **Closed:** 2026-10-23
- **Source:** `.library-remove`, `.account-prompt-dismiss`, and the
  `.button-text` replacement in `app/assets/tailwind/application.css`;
  `app/views/saved_items/index.html.erb`;
  `app/views/shared/_account_prompt.html.erb`.
- **Actual:** Two rules repeated the same transparent, underlined, meta-sized
  text action with different hover colours, and the contracts had no shared
  quiet-action name.
- **Expected:** One documented quiet action with a danger modifier.
- **Resolution:** Added `.button-text` and `.button-text-danger`, migrated both
  consumers, and documented the variant in the Button contract.
- **Verified by:** The two old rules are gone; the views carry the shared
  classes; the library remove action retains its danger hover and named
  accessible label.
