---
sourcesHash: 3c518895a85419ff0fa8f70ef031dc32631d4de550e3e333961cb9db891385a5
id: lyric-entry
description: >-
  Let a visitor find a song by search or paste lyrics manually, then generate a
  print sheet, with search failure never removing the manual path.
status: discoverable
sources:
  - app/views/lyrics/new.html.erb
  - app/javascript/controllers/lyric_search_controller.js
  - app/controllers/lyrics_controller.rb
tests:
  - test/system/organic_conversion_test.rb
  - test/integration/lyrics_flow_test.rb
---

# Lyric entry

## When to use

- The homepage, signed in or out, with or without a songbook token.
- The visitor arrives with a song title, a source URL they expect to paste, or
  lyrics already copied.

## When not to use

- Editing an already generated sheet. There is no separate edit route; the
  entry form is the editing surface.
- The preview or the library.
- A bulk import of many songs. The pattern creates one sheet per submission; a
  songbook is assembled from generated sheets, not entered here.

## Structure

Required regions, in order:

1. **Intro** — `h1`, one paragraph, and the benefits list. The benefits are
   short facts, not marketing claims.
2. **Search** — section heading with the provider note, a labelled search field,
   and a secondary submit. Results appear in the panel attached to the
   composer.
3. **Divider** — names the manual alternative.
4. **Manual form** — title and artist in a two-field row, the lyrics textarea
   with a required note, and the primary "Generate print page" action.

Optional regions:

- **Songbook context** — when the visitor is adding to an existing set, one line
  names the count and links to the set.
- **Results panel** — a header with status/error and close, a list of matching
  songs, and a miss panel. Each match is a submit that loads the lyrics into the
  form.
- **Miss panel** — explains that the source had nothing, offers an external
  lookup and an anchor to the manual textarea, and offers a feedback form.
- **Songbook offer** — the inline offer for a visit holding more than one sheet.

The explainer and FAQ follow the entry panel and are part of the page, not the
task.

## Composition

- Search and manual entry are alternatives that must both remain available.
  A failed, empty, or unreachable search must never hide or disable the manual
  form.
- The search results panel is inside the `lyric_entry` Turbo frame and is
  positioned relative to the composer. It does not push the form down.
- Selecting a result fills the form; it does not create a record. A record is
  created only when the visitor generates the page.
- The miss panel's external lookup opens in a new tab and carries no analytics
  marker, so the query does not reach the destination's URL through this
  application's tracking.
- The manual submit is the one primary action on the page. Search and the miss
  actions are secondary.
- The feedback form inside a miss carries the query as its value and its own
  Turnstile widget; it is a nested form and must stay outside the manual form.
- A songbook token travels in hidden fields on search, result selection, and
  manual submission. Do not drop it when composing a new submit.

## Verification

Static:

- Both forms are present in the response, and neither is inside the other.
- Every input has a label; the search label may be `sr-only`.
- The page has one `h1` and ordered section headings.

Behavioural:

- A search with results lists them and selecting one fills the manual form
  without creating a lyric.
- A search with no results shows the miss panel and leaves the manual form
  usable.
- Submitting the manual form creates the sheet and navigates to the preview.
- Keyboard: Escape and an outside click close the results panel; focus returns
  to the composer.

Commands:

```sh
bin/rails test test/integration/lyrics_flow_test.rb
bin/rails test test/system/organic_conversion_test.rb
```

An intentional violation: hiding the manual form while a search is pending, or
rendering a second form with nested `<form>` tags, must be rejected.
