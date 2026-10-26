# PrintLyrics mobile-first UI redesign plan

- Date: 2026-10-26
- Status: Implemented and verified on 2026-10-26; device/native-print limits are recorded below.
- Direction: A quiet typesetting tool, not a lyrics website.

## Goal

Create a mobile-first lyric-sheet workspace that feels premium through clarity,
reliable editing, and trustworthy print output, not additional decoration.

Core journey: find or paste lyrics → review words → preview and format → print →
optionally keep or extend into a songbook.

Retain the brand's quiet editorial character. Let additional screen width reveal
useful context rather than simply stretching forms or increasing margins.

## Scope

- Homepage and lyric entry.
- Single-sheet editing and preview.
- Songbook navigation and formatting.
- Library and optional account flows.
- Shared navigation, guides, and feedback surfaces.
- Design-system foundations, components, layouts, and contracts.

### Preserve

- Search and manual entry without an account.
- Manual entry when search is unavailable.
- Unlisted, non-indexed generated pages; an unlisted link is not authorization.
- Existing retention and ten-item library rules.
- Four printed text sizes and one/two-column layouts.
- Letter-sized output and browser-based printing/PDF saving.
- Separate print colours, independent of screen theme.

### Exclude

Automatic one-page fitting, additional paper sizes, custom PDF generation,
billing, folders, and new songbook-reordering features.

## Sources and constraints

Reconcile this proposal with the current implementation before beginning work:

- [Product direction](../../PRODUCT.md).
- [Design-system rules](../../DESIGN.md).
- [Rails guidelines](../rails_guidelines.md).
- [Lyric-entry contract](../../design-system/patterns/lyric-entry.md).
- [Print-preview contract](../../design-system/patterns/print-preview.md).
- [Preview-shell contract](../../design-system/layouts/preview-shell.md).
- [Paper-sheet contract](../../design-system/components/paper-sheet.md).
- [Saved-library contract](../../design-system/patterns/saved-library.md).
- [Known design-system gaps](../../design-system/gaps.md).
- [Application routes](../../config/routes.rb).
- [Measurement contract](../measurement-contract.md), if interaction changes
  affect existing analytics hooks.

This plan proposes changes to existing contracts; it does not silently override
those contracts or claim the proposed capabilities already exist. Shared design
work and application behaviour are separate responsibilities. Verify shared
capabilities before migrating their consumers.

## Phase 1 — Define the interaction contract

Resolve behaviour before changing presentation.

### Specify the screen states

| Surface | Required states |
| --- | --- |
| Entry | Search, paste, searching, results, no results, provider failure, loading selected lyrics |
| Editor | Empty, populated, invalid, edited draft, returning from preview |
| Preview | Measuring, ready, multiple pages, formatting changed |
| Songbook | Song selected, per-song formatting, mixed formatting, bulk formatting, save failure |
| Library | Empty, populated, full, save/remove outcome |
| Account | Sign-in required for keeping an item, successful return, validation failure |

### Define editing and persistence

At planning time, lyric routes support creation and viewing, not updating. The
redesign must explicitly distinguish:

- **Draft lyrics:** words being prepared before generation.
- **Generated sheet:** the token-addressed output.
- **Library membership:** whether an account keeps that output.
- **Songbook entry:** a sheet's membership and formatting inside a set.

Recommended baseline: preserve existing generated links when editing; create a
revised sheet rather than silently changing an already-shared sheet.

Before implementing generated-sheet editing, settle how that revision replaces,
or does not replace, a library item or songbook entry. Do not introduce writable
shared-token semantics accidentally. Specify draft lifetime and recovery across
view changes, navigation, and reload rather than implying persistence that the
implementation does not provide.

### Deliverable and gate

A short interaction specification covering navigation, state ownership,
persistence, failure recovery, and keyboard behaviour.

Every visible action must have a defined result, including Back, Cancel,
switching entry modes, and leaving an edited draft. Revision membership semantics
must be resolved before implementing the dependent persistence behaviour.

## Phase 2 — Design the mobile reference screens

Design the narrow layout first, then determine what additional width makes
possible.

### Reference compositions

1. **Entry:** compact introduction, Find/Paste tabs, focused working area.
2. **Review words:** lyrics-first editor with secondary title and artist fields.
3. **Sheet preview:** document-led canvas, page count, Edit lyrics, Format, Print.
4. **Songbook:** accessible song outline and explicit formatting scope.
5. **Library:** restrained saved-item list and clear capacity.
6. **Account:** optional save-and-return flow without losing the current task.

### Responsive behaviour

- Phone: one working surface at a time.
- Mobile formatting: compact dismissible panel, with enough preview exposed to
  inspect the result.
- Mobile editing: full-height surface suitable for the software keyboard.
- Larger screens: inspector beside the preview when both remain usable.
- Wide songbooks: persistent outline only when space supports it.
- Breakpoints follow content constraints rather than one universal threshold.

### Deliverable and gate

Reviewable mobile and desktop compositions, including error and empty states,
not only ideal examples.

The primary task must be obvious at 320px. No important action may depend on
hover, horizontal page scrolling, or discovering an unlabeled icon.

## Phase 3 — Rework and verify shared design capabilities

Retain the semantic-token approach. Change the rules that prevent the new
interaction model.

### Foundations

- Comfortable input and action typography, with 16px text inputs.
- Working touch controls targeting 44–48px rather than shrinking on phones.
- Content-driven layout widths and thresholds.
- Consistent focus, selected, disabled, loading, and error treatments.
- Restrained surface hierarchy: fewer enclosing cards and purposeful borders.
- Dark screen chrome with unchanged white printed paper.
- Reduced-motion behaviour.

### Shared capabilities

| Capability | Responsibility |
| --- | --- |
| Entry-mode tabs | Accessible Find/Paste navigation and preserved input |
| Workspace shell | Document stage, action placement, responsive regions |
| Responsive inspector | Inline desktop panel and mobile presentation |
| Preview viewport controls | Inspection zoom independent of printed typography |
| Song outline | Current-song navigation and accessible location state |
| Formatting controls | Explicit target, selected values, mixed-state communication |
| Field feedback | Associated labels, hints, validation messages, and invalid state |

Extend existing contracts where their responsibilities still fit. Replace
obsolete arrangements rather than maintaining parallel systems. Do not repurpose
the existing formatting segmented control as view navigation; its current
contract excludes that use.

Mobile panels need a visible close action, appropriate focus handling, keyboard
support, safe-area spacing, and a reliable return to the invoking control.

### Deliverable and gate

Updated tokens, shared implementations, contracts, and generated indexes.

Verify shared capabilities in isolation before migrating consumers. Validate
contrast, keyboard operation, touch targets, and mobile panel behaviour. Then
verify each actual product composition after migration.

## Phase 4 — Implement the complete single-sheet journey

This is the first end-to-end milestone.

### Entry and review

- Replace stacked search/manual sections with accessible modes.
- Preserve both modes' input during switching and failed searches.
- Put mobile search results in normal document flow.
- Keep result selection separate from record creation.
- Make the lyrics field the primary editing surface.
- Rename the generation action to **Preview sheet**, while preserving its actual
  persistence semantics.
- Reduce introductory copy and remove the benefits checklist from the working
  area.
- Keep account navigation quiet and avoid competing account-creation actions.

### Workspace

- Introduce the document-led preview shell.
- Keep Print as the primary action.
- Move formatting into the responsive inspector.
- Separate preview magnification from printed text size.
- Preserve words and formatting when returning to edit.
- Show measured page counts after layout.
- Keep optional saving and songbook creation secondary.
- Explain browser-based PDF saving without implying a separate export service.

### Acceptance and gate

A signed-out visitor can search or paste, review, generate, format, return to
editing without losing work, and print.

Check short and long lyrics, long titles, stanza boundaries, all supported sizes,
and both column layouts. Exercise the actual browser flow and compare preview
against generated PDF output. Passing application tests alone is insufficient.

## Phase 5 — Extend the workspace to songbooks

Reuse the single-sheet interaction model rather than designing another toolbar
system.

### Changes

- Compact song outline on mobile; persistent outline where space permits.
- Selecting a song navigates to its first page.
- Formatting names the song it will change.
- Whole-book formatting remains visibly distinct.
- Mixed values are represented honestly.
- Bulk changes affect only the selected dimension.
- Adding a song preserves book context throughout entry.
- Layout-save failures are visible and actionable.
- Removing a song keeps navigation and page counts coherent.

### Acceptance and gate

- Formatting one song leaves others unchanged.
- Changing all text sizes preserves intentionally different column counts.
- Reload restores persisted formatting.
- Current-song indication remains correct after scrolling and repagination.
- Every song and continuation page prints in the expected order.
- No outline, inspector, action bar, or status message reaches paper.

Verify a multi-song book with mixed formatting and songs spanning multiple pages.

## Phase 6 — Migrate supporting surfaces

### Library and accounts

- Apply the new hierarchy and touch sizing.
- Keep capacity informational rather than dominant.
- Distinguish sheets from songbooks.
- Make removal consequences clear.
- Preserve the current item through authentication.
- Keep account creation optional and secondary to printing.

### Guides, feedback, and navigation

- Apply shared typography, controls, spacing, and field feedback.
- Keep guides readable rather than turning them into workspace screens.
- Remove duplicate navigation and obsolete UI treatments.
- Preserve public indexing boundaries.

### Gate

Every supported surface belongs to the same system. No legacy component
arrangement remains solely because it was outside the main happy path.

## Phase 7 — Final verification and documentation

### Browser coverage

Check representative widths of 320, 390, 768, 1280, and 1600px, plus:

- Light and dark themes.
- Keyboard-only navigation and visible focus.
- Browser zoom and enlarged text.
- Mobile keyboard and safe-area interactions.
- Long content and multiple printed pages.
- Search failure and layout-save failure.
- Empty and full library states.

Automated viewport checks do not establish software-keyboard or native print
behaviour. Exercise those on an appropriate browser/device and report any
remaining verification limitation.

### Repository checks

Run relevant focused tests after each coherent implementation milestone, then
the appropriate final suite:

```sh
bin/rails test
bin/rails test:system
bin/rails tailwindcss:build
bin/rails assets:precompile
```

Run RuboCop for changed Ruby files and the design-system contract and index
checks documented in [DESIGN.md](../../DESIGN.md#verification). Add permanent
regression tests for consumer-visible state, persistence, scope, and error
behaviour, not incidental markup or wording.

Update DESIGN.md, affected contracts, and product guidance where behaviour
changes. Regenerate indexes after editing contracts. Leave release-managed
changelog/version files alone. Remove temporary verification scaffolding after
runtime proof.

### Environment prerequisite

During design exploration on 2026-10-26, the local server reported
`ActiveRecord::PendingMigrationError`. Reassess the environment before
implementation verification and resolve outstanding setup through an approved
path. Do not automatically migrate or disturb the existing development server.
Do not start another server on port 3000 or signal the developer's server PID.

## Definition of done

- The full task works comfortably on a phone.
- Wider screens reveal useful context rather than stretched forms.
- Editing and navigation do not silently lose work.
- Formatting scope is unambiguous.
- Preview and printed output agree.
- Optional accounts remain optional.
- Shared contracts describe the shipped behaviour.
- Browser and print evidence cover the changed flows.
- All affected callers and supporting surfaces use the new system without
  obsolete compatibility paths.

Execution order: interaction contract → reference screens → shared capabilities
→ complete single-sheet journey → songbooks → supporting surfaces → final
verification.

## Implementation and verification record

The [interaction specification and reference compositions](2026-10-26-002-mobile-workspace-interaction.md)
resolve state ownership, navigation, recovery and independent revision semantics.
The shipped interface is the visual reference at phone and wide widths.

- Find/Paste tabs retain both inputs; review puts words before metadata.
  Tab-scoped drafts survive mode changes, search failure and reload. A completed
  preview clears only its own draft.
- Edit lyrics preserves words and formatting in an independent revision. Existing
  links, library membership and songbook entries remain unchanged.
- A document-led workspace separates inspection zoom from printed typography.
  Its mobile inspector has an always-visible Close action, Escape/focus return,
  safe-area spacing and an inline desktop presentation.
- Songbooks provide an outline, named current-song controls, explicit mixed
  whole-book values, dimension-only changes and visible, retryable save failures.
  Failure feedback stays below the measured action band while reading later pages.
- Library/account/guide/feedback surfaces use the same type and target sizing.
  Library removal explains retention; optional account save-and-return remains
  intact. Contextual guide prose links remain, without duplicate global menus.
- Contracts, indexes and guidance describe the shipped behavior. G1, G2, G3,
  G10 and G11 are resolved in the gap archive; no release-managed files changed.

### Repository evidence

| Check | Observed result |
| --- | --- |
| `bin/rails test` | 336 runs, 1,554 assertions; 0 failures, 0 errors, 0 skips |
| `bin/rails test:system` | 42 runs, 326 assertions; 0 failures, 0 errors, 0 skips |
| RuboCop on changed Ruby files | 15 files; no offenses |
| `bin/rails tailwindcss:build` | Passed |
| `bin/rails assets:precompile` | Passed |
| Contract checks and generated indexes | All 17 contracts pass; indexes current |

### Browser and print evidence

Eight surfaces were checked at 320, 390, 768, 1280 and 1600px in light/dark
themes: 80 states, no horizontal body overflow, no working targets below 44px,
and no text inputs below 16px. All eight also passed 200% enlarged-text reflow
at 320px. Keyboard tabs, inspector Escape/focus return, reduced motion, invalid
account fields, search failure, layout failure/retry, empty/full library states,
save/remove outcomes and adding/removing book songs were exercised.

Live search returned five matches; a temporary selected-lyrics failure retained
the retry and manual-entry paths. Source selection success is covered by the
browser regression suite. Rendered text contrast stayed above 4.5:1 and focus/
control contrast above 3:1 in both themes.

For 36 stanzas and a long title, every supported size/column combination
preserved all verses without column overflow and matched its generated PDF:

| Text size | Columns | Preview pages | PDF pages |
| --- | --- | --- | --- |
| S | 1 | 4 | 4 |
| S | 2 | 3 | 3 |
| M | 1 | 5 | 5 |
| M | 2 | 4 | 4 |
| L | 1 | 6 | 6 |
| L | 2 | 4 | 4 |
| XL | 1 | 7 | 7 |
| XL | 2 | 5 | 5 |

The actual PDF was rasterized and compared with the preview. The print-only
scan mark remains; skip link, inspector, outline, controls and status do not.
A mixed-format, multi-page book persisted per-song formatting across reload.
Bulk text-size changes retained different column counts; its five-page PDF
kept continuation pages before the final song. Removing that song remeasured
the remaining book to four pages.

### Environment and limits

The existing port-3000 server still reported pending migrations and was left
untouched. Verification used this worktree's already-current test database and
an isolated port-3107 server with its own PID; that server was stopped afterward.
Tests ran without the separate browser server sharing the SQLite database.

Native software-keyboard behavior, real-device safe-area behavior, browser-chrome
zoom controls, the OS print/Save as PDF picker and physical printer output were
not exercised. Responsive/enlarged-text checks and Chromium-generated PDFs cover
the available browser surface; they do not establish those native/device results.
