# Design-system gaps

Open entries only. Closed entries move in full to
[gaps-archive.md](gaps-archive.md).

## G1 — Form errors are summarised but not associated with their fields

- **Status:** Open
- **Date:** 2026-10-23
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

- **Status:** Open
- **Date:** 2026-10-23
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

- **Status:** Open
- **Date:** 2026-10-23
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

- **Status:** Open
- **Date:** 2026-10-23
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
