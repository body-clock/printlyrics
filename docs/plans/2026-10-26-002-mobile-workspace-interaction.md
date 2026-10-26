# Mobile workspace interaction specification

Implementation companion to [the redesign plan](2026-10-26-001-mobile-first-ui-redesign-plan.md).

## Ownership and persistence

- A draft is editable browser state, not a saved sheet. Find and Paste are entry modes; switching modes never clears either input. Selecting a search result opens review without creating records. Preview sheet creates a token-addressed sheet, exactly as the former generation action did.
- Draft recovery uses tab-scoped session storage, keyed separately for a new sheet, adding to a particular songbook, and revising a particular sheet. It survives reload and visits within that tab; closing the tab ends recovery. Storage may be unavailable: the form remains usable, but recovery must not claim success. Lyrics and draft identifiers never enter analytics.
- A generated sheet is immutable. Edit lyrics opens a new draft copied from the sheet; Preview sheet creates an independent revision. The original shared link remains unchanged. Library membership does not transfer and songbook entries are not replaced. The editor explains these consequences. Cancel returns to the original sheet without writing. Adding to a book retains that book's context on every search/select/submit.
- Sheet formatting uses the existing browser preference store; revisions retain the current formatting preference. Songbook entry formatting is persisted on the server, separately from lyric text and library membership. An unlisted token is not authorization.
- Library membership keeps an existing output, subject to the existing combined ten-item limit. Authentication retains the pending item and returns to it; printing never requires authentication. Removal removes only library membership, not the underlying shared output, and restores ordinary retention.

## State and failure contract

| Surface | State and result |
| --- | --- |
| Find | Empty query, searching, matches, no matches, provider error, loading selection. Inputs remain editable after failure; Paste remains reachable. Retry selected lyrics without repeating search. Results occupy document flow. |
| Review | Empty or populated words, optional title/artist, associated invalid fields, modified/recovered draft. Words precede metadata. Native required constraints and server validation preserve submitted text. Deliberate result selection must not silently replace an edited draft. |
| Navigation | Find/Paste preserves input; Cancel revision returns to original. Back uses browser history and recoverable draft. Leaving modified words warns before discarding unrecovered changes. Successful preview is not an abandoned edit. |
| Preview | Measuring before a page count is available; ready with measured count; multiple pages; immediate repagination after formatting. Print is primary. Browser print includes Save as PDF; no custom export service is implied. |
| Format | Explicit text-size and column selections. Preview zoom changes only screen magnification. Mobile panel is nonmodal: preview stays visible, Close and Escape dismiss, focus returns to Format. Wide layout shows the inspector inline. |
| Songbook | Outline selects first page of song. Scroll/repagination updates current location. Per-song controls name their target. Whole-book controls are distinct and show mixed values rather than pretending the first song represents all. Bulk changes send only the changed dimension. Failed saves remain visible and retryable; subsequent success must not conceal earlier unsaved changes. |
| Library | Empty first-sheet action, saved list with item kinds, understated capacity, full explanation, save/remove outcome. Removing membership does not invalidate shared links. |
| Account | Optional keep-and-return, failed validation with associated fields, successful return to item, cancel back to current task. Google first when configured; email fallback. |

## Keyboard and accessibility

Find/Paste uses tabs with roving focus, Left/Right, Home/End and associated panels. Every action has text or an accessible name. Native buttons activate on Enter/Space. Formatting buttons expose pressed state; mixed values have visible text. Focus uses the opaque shared ring. Search status and page counts announce politely, errors are associated and announced. Mobile inspector has a labelled region, visible close action and Escape handling; it is not a dialog that traps access to the preview. Working controls are at least 44px; text inputs are 16px. Reduced motion removes spinner animation and transitions.

## Reference compositions

These are structural references, not a second visual system. Existing semantic colours, serif headlines, system UI text and physical white paper remain authoritative. Phone uses one working surface; extra width reveals useful context.

| Surface | Phone reference | Wide reference | Empty/error composition |
| --- | --- | --- | --- |
| Entry | Quiet brand/sign in; compact heading; Find/Paste tab row; query/action; in-flow results. | Readable centred working column, not stretched controls. | In-flow provider error or no-results note with retry/manual route. |
| Review | Words-first tall textarea; optional metadata below; Preview sheet and cancel. | Longer readable editing measure; metadata pair. | Inline field error and preserved text; recovery status above words. |
| Sheet | Compact task band; page count/zoom; fitted paper; Format opens bottom panel; optional keep below paper. | Paper stage with right-hand inspector. | Measuring status in place of fabricated page count. |
| Songbook | Song outline disclosure above paper; current-song format target in inspector. | Persistent left outline, paper centre, formatting right when all three fit. | Visible save-failure region with retry; mixed formatting shown as text. |
| Library | Heading/capacity; restrained rows with kind/title/actions. | Same readable list with aligned actions, not dashboard cards. | Empty-state first-sheet action; full state explains removing membership. |
| Account | Narrow heading and one form panel; optional keep context and return action. | Same bounded form measure. | Error summary plus associated invalid fields; pending item retained. |

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 920 420" fill="none" stroke="var(--border)">
  <g font-family="system-ui,sans-serif" font-size="14" fill="currentColor" stroke="none">
    <text x="16" y="22">Phone · one task at a time</text>
    <text x="355" y="22">Wide · context beside the document</text>
  </g>
  <rect x="16" y="40" width="280" height="360" rx="6"/>
  <path d="M16 92H296 M16 148H296 M16 320H296"/>
  <rect x="42" y="170" width="228" height="128"/>
  <g font-family="system-ui,sans-serif" font-size="14" fill="currentColor" stroke="none">
    <text x="32" y="72">Edit lyrics     Format     Print</text>
    <text x="32" y="125">2 pages        Preview: Fit</text>
    <text x="64" y="215">The paper stays visible</text>
    <text x="32" y="348">Format this sheet        Close</text>
    <text x="32" y="380">Text size   S   M   L   XL</text>
  </g>
  <rect x="355" y="40" width="549" height="360" rx="6"/>
  <path d="M355 92H904 M486 92V400 M755 92V400"/>
  <rect x="510" y="122" width="220" height="254"/>
  <g font-family="system-ui,sans-serif" font-size="14" fill="currentColor" stroke="none">
    <text x="371" y="72">Songbook                         Edit lyrics      Print</text>
    <text x="370" y="125">Songs</text>
    <text x="370" y="165">1. First song</text>
    <text x="370" y="204">2. Current song</text>
    <text x="544" y="162">Title of the song</text>
    <text x="544" y="205">Words, not chrome.</text>
    <text x="770" y="125">Current song</text>
    <text x="770" y="165">Text size</text>
    <text x="770" y="204">S  M  L  XL</text>
    <text x="770" y="248">Columns</text>
    <text x="770" y="287">1    2</text>
    <text x="770" y="345">Whole book</text>
  </g>
</svg>
```

Responsive boundaries follow usable content: metadata collapses below 560px; readable/prose support below 700px; inspector appears inline only when the document and inspector fit (1100px); a third outline column requires 1440px. At intermediate widths the outline remains a disclosure. Paper always fits its own available stage; inspection zoom may scroll inside that stage, never the document body. Print resets the stage, scale and grid; no chrome reaches paper.
