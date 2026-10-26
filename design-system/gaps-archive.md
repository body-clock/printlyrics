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

## G1 — Form errors are summarised but not associated with their fields

- **Status:** Resolved
- **Date:** 2026-10-23
- **Closed:** 2026-10-26
- **Resolution:** Added the shared `field_feedback_attributes` helper and
  `shared/field_feedback` partial, with record-backed `aria-invalid`, error IDs
  and associated hints; migrated entry, registration, reset and feedback fields.
- **Verified by:** Browser validation on `/account/new` confirmed both invalid
  password fields reference existing inline messages; focused account/feedback
  integration checks pass. The Field contract defines the common API.
- **Category:** Accessibility / contract drift
- **Source:** [form-errors.md](components/form-errors.md),
  [field.md](components/field.md), `app/views/registrations/new.html.erb`,
  `app/views/passwords/edit.html.erb`, `app/views/feedbacks/new.html.erb`.
- **Actual:** A failed form renders one `.form-errors` block with
  `role="alert"` and `full_messages.to_sentence`. The invalid controls keep their
  labels but do not carry `aria-invalid` or an error description, and there are
  no per-field messages.
- **Expected:** Each invalid control exposes its invalid state and its message to
  assistive technology, while the form keeps one announced summary. A visitor
  navigating by field should hear why that field is wrong.
- **Why it is systemic:** Every form uses the same error summary and field
  component; fixing one view would create a second convention.
- **Next actionable step:** Decide the per-field error API (model errors map to
  fields, or a view-local map), then extend the field contract and the error
  summary together. The controller/model mapping is project logic; the design
  contract only owns the visible and announced association.
- **Decision needed:** None yet; the per-field source of truth is unresolved.

## G2 — The search-results close control has no managed component

- **Status:** Resolved
- **Date:** 2026-10-23
- **Closed:** 2026-10-26
- **Resolution:** Explicitly retained the search close control as pattern-private
  in the lyric-entry contract; it is not a second general button API.
- **Verified by:** Live mobile search showed a named Close search results control
  measuring 44 by 44px; the contract requires that name and target.
- **Category:** Coverage
- **Source:** `app/views/lyrics/new.html.erb`, `.search-results-close` in
  `app/assets/tailwind/application.css`.
- **Actual:** The icon-only close button is styled locally and documented only
  as part of the [lyric-entry](patterns/lyric-entry.md) pattern. It uses
  `--control-icon`, `--icon-md`, and the circular-mark conventions without a
  component contract.
- **Expected:** A reusable icon-only control contract with a required accessible
  name, size selection, and disabled/hover states, or an explicit decision that
  this control remains pattern-private.
- **Next actionable step:** Add an `icon-button` component when a second
  consumer appears, or record the pattern-private decision in the lyric-entry
  contract. Do not invent a new visual style for the next icon control.
- **Decision needed:** Whether one consumer justifies a component.

## G3 — Footer and account text links are below the 24px target

- **Status:** Resolved
- **Date:** 2026-10-23
- **Closed:** 2026-10-26
- **Resolution:** Standalone footer/account links now use inline-flex and the
  shared 44px target, rather than relying on an inline-link exception.
- **Verified by:** The current-source 80-state browser matrix (320, 390, 768,
  1280 and 1600px, both themes, eight surfaces) found no undersized working
  targets or horizontal body overflow. Footer links each measured 44px.
- **Category:** Accessibility
- **Source:** `.site-footer-nav a` and `.account-links a` in
  `app/assets/tailwind/application.css`; `app/views/shared/_site_footer.html.erb`;
  the account views.
- **Actual:** Footer navigation links render at `--text-meta` with a normal
  line box (about 18px tall), and the account links are single inline links in
  paragraphs. The card and dismiss actions now have a 24px minimum target, but
  these do not.
- **Expected:** Every standalone text action meets WCAG 2.2 Target Size
  (Minimum), or the inline-link exception is documented as the reason it does
  not.
- **Next actionable step:** Decide whether footer navigation links are inline
  text (exception) or standalone actions needing a 24px target. If standalone,
  add the same `inline-flex`/`min-height` treatment and re-check the footer at
  320px.
- **Decision needed:** Whether the inline-link exception applies.

## G10 — The compact songbook dismiss is a local button variant

- **Status:** Resolved
- **Date:** 2026-10-23
- **Closed:** 2026-10-26
- **Resolution:** Removed the local bordered dismiss class/rules. The prompt now
  uses the existing unbordered `.button-text`; no third quiet-action tier is
  needed and no border exception remains.
- **Verified by:** The rendered songbook dismiss measured 44px high, matched the
  Button contract and preserved the existing dismiss outcome in browser tests.
- **Category:** Coverage / variant drift
- **Source:** `app/views/shared/_songbook_prompt.html.erb`,
  `.songbook-prompt-dismiss` in `app/assets/tailwind/application.css`.
- **Actual:** The dismiss is a bordered, low-emphasis action with its own
  padding and hover fill. It is not `.button-text` (unbordered) and not a
  `.button` size (too tall for the strip).
- **Expected:** The system has one documented compact-bordered action variant,
  or the prompt uses the existing text action with a documented reason for the
  border.
- **Next actionable step:** Decide whether the system needs a third quiet action
  level. Until then, treat the control as private to the inline offer and do not
  copy its rules.
- **Decision needed:** Whether to add a compact-outline variant.

## G11 — Placeholder text failed normal-text contrast

- **Status:** Resolved
- **Date:** 2026-10-26
- **Closed:** 2026-10-26
- **Resolution:** The placeholder role now aliases the opaque secondary-text
  tone. Labels, placeholder semantics and print colours are unchanged.
- **Verified by:** Actual input compositing in Chromium measured 6.42:1 in
  light mode and 6.09:1 in dark mode after transitions settled. The Tailwind
  build and production asset compilation passed.
- **Category:** Accessibility / contrast
- **Source:** `--content-placeholder` and `.field input::placeholder` in
  `app/assets/tailwind/application.css`.
- **Actual:** The placeholder token diluted secondary text to 80% opacity.
  Browser compositing measured 4.03:1 on the light input surface, below 4.5:1.
- **Expected:** Placeholder text meets normal-text contrast in both themes;
  it never replaces a label.
- **Next actionable step:** Use the existing opaque secondary-text tone for the
  placeholder role and verify the actual rendered input in both themes.
- **Decision needed:** None; the shared text-contrast rule already requires it.
