---
title: Popularity-Led Song Catalog - Plan
type: feat
date: 2026-08-05
topic: popularity-led-song-catalog
artifact_contract: ce-unified-plan/v1
artifact_readiness: implementation-ready
product_contract_source: ce-brainstorm
execution: code
---

# Popularity-Led Song Catalog - Plan

## Goal Capsule

- **Objective:** Rework `/songs` into a current, useful acquisition surface that highlights up to 20 popular printable songs and preserves a browseable catalog of other working song pages.
- **Product authority:** This plan owns catalog admission, popularity refresh behavior, the `/songs` information hierarchy, song-page discovery, and catalog measurement. It preserves the lyric-loading and print workflow defined in `PRODUCT.md` and the metadata-only indexation boundary established by `docs/plans/2026-07-28-001-feat-organic-search-growth-plan.md`.
- **Open blockers:** None. Feed use proceeds under the explicit assumption recorded in Key Decisions and Dependencies and Assumptions.
- **Execution profile:** Standard-depth Rails change with a schema migration, two HTTP integrations, catalog UI changes, privacy-bounded analytics, and operational scheduling.
- **Authority order:** Product Contract and its session-settled decisions; Planning Contract; implementation-unit boundaries; existing repository conventions where this plan is silent.
- **Stop conditions:** Stop rather than publish if the Apple response is invalid, no candidate can be confidently matched, a proposed change would put lyrics in an indexable response, or Apple attribution cannot be rendered from feed data.
- **Tail ownership:** The implementation run owns migration, tests, documentation, browser verification, and a review-ready pull request; the site owner owns installing the weekly host schedule and monitoring external consoles.

---

## Product Contract

### Summary

Rework `/songs` into the canonical popularity-led catalog.
The page leads with up to 20 songs refreshed weekly from Apple's current US top-songs feed, then presents an alphabetical archive of other working song pages.

### Problem Frame

The current catalog is an alphabetical projection of a fixed 20-song launch seed plus songs promoted by PrintLyrics usage.
It has no recurring external popularity signal, so its claim to present popular songs becomes stale and its most prominent entries do not adapt to current interest.

The opportunity is not to generate a large song directory.
It is to keep one bounded catalog surface timely while every song link remains a direct path to the working print tool.

### Key Decisions

- **Rework `/songs` instead of adding a separate trends page.** (session-settled: user-directed — chosen over a standalone Popular Now page: the existing route and its catalog system are the intended center of the change.) Governs R1-R4.
- **Use Apple's credential-free US Marketing Tools feed.** (session-settled: user-approved — chosen over Spotify, authenticated Apple Music APIs, and multi-country aggregation: one credential-free feed keeps the first release small.) Governs R5-R8.
- **Publish the weekly refresh automatically.** (session-settled: user-directed — chosen over human approval: the user prefers a bounded unattended refresh with validation.) Governs R6-R9.
- **Use a two-tier catalog.** (session-settled: user-approved — chosen over a current-only page or one blended ranking: freshness leads while the archive remains stable and browseable.) Governs R1-R4, R10-R13.
- **Preserve all defensible admission paths.** (session-settled: user-approved — chosen over an Apple-only archive: Apple popularity, demonstrated PrintLyrics use, and the legacy launch seed may all support a working song page.) Governs R9-R13.
- **Measure qualified acquisition first.** (session-settled: user-directed — chosen over impressions or completed print flows as the primary signal: an organic visitor beginning lyric loading shows that the landing page reached the working tool.) Governs R18-R20.
- **Proceed under an explicit Apple feed-use assumption.** (session-settled: user-directed — chosen over pausing for legal confirmation or replacing Apple with open data: title and artist metadata will be used with Apple attribution and destination links without treating that choice as legal assurance.) Governs R21.

### Actors

- A1. **Catalog visitor:** Browses current or archived songs and wants to load lyrics into a printable sheet.
- A2. **Search visitor:** Lands on `/songs` or a song page from organic search and decides whether to begin lyric loading.
- A3. **Site owner:** Operates the weekly refresh and evaluates catalog quality, acquisition, and conversion.
- A4. **Apple Marketing Tools feed:** Supplies the current ranked US song candidates.
- A5. **LRCLIB:** Supplies the printable-song match and remains the authority for lyric availability.
- A6. **Search engine:** Crawls the catalog hierarchy and eligible metadata-only song pages.

### Requirements

**Catalog experience**

- R1. `/songs` must remain the canonical browse route and present a Popular Now section before the archive.
- R2. Popular Now must show up to 20 songs in Apple rank order, identify the list as current US popularity, and show the last successful refresh date.
- R3. The archive must exclude the current Popular Now songs, order remaining eligible songs alphabetically by artist and title, and retain ordinary crawlable pagination.
- R4. Every catalog entry must lead to one metadata-only song page whose primary action loads available lyrics into the existing editable print workflow.

```mermaid
flowchart TB
  Songs[/songs] --> Current[Popular Now: up to 20]
  Songs --> Archive[Alphabetical archive]
  Current --> Song[Metadata-only song page]
  Archive --> Song
  Song --> Load[Load lyrics to print]
```

**Weekly popularity refresh**

- R5. The popularity source must be Apple's credential-free US Marketing Tools top-songs feed, sampled once per week.
- R6. Each refresh must request 25 ranked candidates and evaluate them in source order until it finds 20 confidently matched, printable LRCLIB songs or exhausts the candidate list.
- R7. A missing or ambiguous LRCLIB match must be skipped without creating or promoting a song page.
- R8. A failed or invalid Apple response must leave the last successful Popular Now list unchanged and must not publish a partial replacement.
- R9. A successful refresh must be idempotent: persistent candidates retain their existing URLs, new matches become eligible, and departed candidates lose only their Popular Now placement.

**Admission and lifecycle**

- R10. The archive must include eligible former Popular Now songs, songs promoted through the existing successful-print threshold, and the existing 20 legacy-seeded songs.
- R11. Leaving Popular Now must not by itself remove, demote, or request `noindex` for a working song page.
- R12. A confirmed LRCLIB not-found result must remove a song from Popular Now and the archive, remove it from the sitemap, and serve the existing unavailable-page behavior.
- R13. A transient LRCLIB failure must preserve the song's last known public state for later retry.

**Search integrity**

- R14. `/songs`, its archive pagination, and every eligible song page must remain canonical, indexable, linked through the visible hierarchy, and represented in the sitemap.
- R15. Initial indexable responses must never contain lyric text; lyrics remain behind the visitor's explicit load action.
- R16. Popularity refreshes must not generate artist pages, keyword variants, or pages for songs that fail the working-tool gate in R7.
- R17. The catalog must follow Google's people-first and spam policies by keeping expansion bounded, avoiding doorway variants, and giving each song page a direct working purpose beyond search capture.

**Measurement**

- R18. Measurement must distinguish organic visits that begin lyric loading from visits that only view `/songs` or a song page.
- R19. Catalog measurement must distinguish Popular Now, archive, and direct-entry paths using low-cardinality context without recording song titles, artists, source identifiers, lyrics, or lyric tokens.
- R20. Supporting reporting must retain completed print-flow and Search Console visibility signals so acquisition quality is reviewed alongside impressions, clicks, and print outcomes.

**Source attribution**

- R21. Popular Now must identify Apple as its ranking source and link each listed song to the corresponding Apple destination supplied by the feed.

### Key Flows

- F1. **Weekly catalog refresh**
  - **Trigger:** The scheduled weekly refresh starts.
  - **Actors:** A3, A4, A5
  - **Steps:** Fetch 25 US top-song candidates, evaluate them in rank order, retain up to 20 valid printable matches per R6, and reconcile Popular Now against the prior successful list.
  - **Outcome:** `/songs` reflects the latest successful bounded snapshot without changing persistent song URLs.
  - **Covers:** R2, R5-R9, R13.
- F2. **Current-song discovery**
  - **Trigger:** A1 or A2 opens `/songs` and selects a Popular Now entry.
  - **Actors:** A1 or A2, A5
  - **Steps:** The visitor opens the metadata-only song page, invokes lyric loading, reviews the editable result, and continues into the print workflow.
  - **Outcome:** A timely song discovery becomes a qualified tool visit without exposing lyrics to the index.
  - **Covers:** R1, R2, R4, R15, R18-R20.
- F3. **Archive discovery**
  - **Trigger:** A1 browses beyond the current list or A2 lands on an older eligible page.
  - **Actors:** A1 or A2, A6
  - **Steps:** The visitor reaches the page through the alphabetical archive or search, then uses the same lyric-loading flow.
  - **Outcome:** Older working pages remain useful, discoverable, and distinguishable from current popularity.
  - **Covers:** R3, R4, R10, R11, R14, R18-R20.
- F4. **Availability loss**
  - **Trigger:** A5 definitively reports that an indexed song is no longer printable.
  - **Actors:** A3, A5, A6
  - **Steps:** The catalog removes the song from both browse sections and the sitemap, and the song URL serves the existing unavailable state.
  - **Outcome:** Public discovery contains only working song flows.
  - **Covers:** R12-R14.

### Acceptance Examples

- AE1. **Covers R2, R6, R7.** Given Apple returns 25 candidates and five higher-ranked candidates cannot be matched confidently, when the refresh succeeds, then Popular Now contains the first 20 valid matches in their original relative rank order.
- AE2. **Covers R8.** Given Apple times out or returns invalid data, when the refresh runs, then the prior Popular Now list and its refresh date remain unchanged.
- AE3. **Covers R3, R9-R11.** Given a working song leaves Apple's selected set, when the refresh succeeds, then it disappears from Popular Now, appears in its alphabetical archive position, and keeps its existing URL and index eligibility.
- AE4. **Covers R2, R3.** Given a song is in the current Popular Now set, when `/songs` renders, then the song appears once in Popular Now and is absent from the archive section.
- AE5. **Covers R10.** Given the first Apple refresh replaces most launch candidates, when `/songs` renders, then the displaced legacy-seeded songs remain in the alphabetical archive while still available.
- AE6. **Covers R10.** Given a non-chart song reaches the existing successful-print threshold, when it becomes eligible, then it joins the alphabetical archive without entering Popular Now.
- AE7. **Covers R12-R14.** Given LRCLIB definitively no longer has a song, when availability is verified, then the song leaves both browse sections and the sitemap and its URL serves the unavailable state.
- AE8. **Covers R4, R15, R17.** Given a crawler requests `/songs` or a song page, when the response renders, then it exposes useful metadata and crawlable navigation but no lyric text.
- AE9. **Covers R18-R20.** Given an organic visitor starts lyric loading from a Popular Now song, when analytics records the action, then it identifies the Popular Now path without including song or lyric metadata.
- AE10. **Covers R21.** Given Popular Now contains an Apple candidate, when `/songs` renders, then the section identifies Apple as the ranking source and provides the feed-supplied Apple destination for that song.

### Success Criteria

- Qualified organic visits that invoke lyric loading are the primary outcome and are reported separately for Popular Now, archive, and direct song-page entry.
- Organic print-page generation and print-dialog opens are reviewed as supporting conversion signals rather than substitutes for qualified acquisition.
- Search Console impressions, clicks, index coverage, and exclusion reasons are reviewed alongside product actions so page growth without tool use is not treated as success.
- The first 30 and 90 days establish a baseline because no pre-launch evidence supports a numerical target; later targets must be set from observed qualified-visit conversion.
- Search Console shows no indexed lyric sheets, no doorway variants, and no unexpected growth beyond the bounded catalog admission rules.

### Scope Boundaries

- Multi-country Apple aggregation and localization beyond the existing English product interface.
- Spotify, Billboard scraping, Google Trends, authenticated Apple Music APIs, and additional popularity providers.
- Artist pages, album pages, keyword-variant pages, and automated prose about trending songs.
- Lyric text in indexable responses, ranking guarantees, paid acquisition, and lyrics licensing.
- Removing working legacy or departed song pages merely because their current popularity declined.

### Dependencies and Assumptions

- Apple's US Marketing Tools feed remains credential-free, machine-readable, and available for weekly use.
- PrintLyrics assumes that using feed-supplied title and artist metadata with Apple attribution and destination links is permitted; this is a user-accepted operating assumption, not legal assurance.
- Apple rank is a useful popularity proxy, not a measurement of Google lyric-search demand.
- LRCLIB can confidently match enough of 25 Apple candidates to keep Popular Now near its 20-song target.
- The existing organic admission threshold, metadata-only song pages, availability verifier, sitemap, and privacy-safe analytics remain valid foundations.
- The deployment environment can run one non-overlapping weekly task and retain its outcome for operational review.

### Outstanding Questions

No launch-blocking questions remain. The host scheduler's exact clock time may be changed operationally without changing the weekly contract; the documented default is Monday at 09:00 UTC.

### Sources and Research

- `PRODUCT.md` defines the focused print workflow, product users, and quiet brand posture.
- `docs/plans/2026-07-28-001-feat-organic-search-growth-plan.md` owns the metadata-only indexation, browseable hierarchy, demand-led admission, measurement, and anti-spam foundations this work extends.
- `app/controllers/songs_controller.rb` and `app/views/songs/index.html.erb` implement the current alphabetical `/songs` catalog.
- `app/models/song.rb` implements current eligibility and the three-successful-print promotion threshold.
- `db/seeds.rb` defines the 20-song legacy launch catalog.
- `app/controllers/sitemaps_controller.rb` publishes eligible catalog and song URLs.
- `lib/tasks/songs.rake` and `app/models/song_catalog_verifier.rb` provide the current scheduled catalog-maintenance pattern.
- [Apple Marketing Tools US top-songs feed](https://rss.marketingtools.apple.com/api/v2/us/music/most-played/25/songs.json) is the selected popularity source; Apple's former `rss.applemarketingtools.com` host redirects here.
- [Apple RSS information](https://www.apple.com/ca/rss/) documents Apple's public chart-feed family.
- [Apple Marketing Resources and Tools](https://performance-partners.apple.com/tools) says its RSS Generator may be used to incorporate top-music lists into websites.
- [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/) provides the closest published Apple Music feed attribution and promotional-use restrictions; the selected public feed's exact applicability remains an accepted assumption rather than legal assurance.
- [Google people-first content guidance](https://developers.google.com/search/docs/fundamentals/creating-helpful-content) warns against publishing content merely because it is trending or primarily to attract search visits.
- [Google spam policies](https://developers.google.com/search/docs/essentials/spam-policies) define doorway abuse and scaled content abuse relevant to catalog expansion.

---

## Planning Contract

### Key Technical Decisions

- KTD1. **Keep chart state on `songs`.** Add nullable Apple identity, Apple destination, current rank, and refresh timestamp columns to the existing record rather than introducing chart and snapshot tables. One bounded current list is the only product state required; index eligibility already owns long-lived page admission. This instantiates R2, R3, R9-R11.
- KTD2. **Replace popularity atomically after all external work succeeds.** Fetch and validate Apple candidates, resolve LRCLIB matches, and build the complete proposed list before opening a database transaction. Inside the transaction, clear prior ranks and assign the new ranks and a shared refresh time. Apple or LRCLIB service failures abort before reconciliation so the prior snapshot and date remain unchanged. This instantiates R6-R9 and R13.
- KTD3. **Use strict, Unicode-aware title and artist equivalence.** Normalize titles and artist credits with NFKC Unicode normalization, case folding, punctuation-to-space conversion, whitespace collapse, and removal of leading `the` only for artist comparison. Accept one printable LRCLIB result only when normalized titles are equal and artist credits are equal; if more than one result passes, treat the candidate as ambiguous and skip it. Do not strip version-bearing title text such as remix, live, acoustic, or remastered. This favors false negatives over incorrect SEO pages and instantiates R7, R16, and R17.
- KTD4. **Search more broadly without changing the public LRCLIB search contract.** Add a dedicated client method that returns a larger bounded candidate set for catalog matching, leaving the existing five-result user search behavior intact. Query with Apple title and artist together, deduplicate feed candidates by Apple identity and accepted matches by LRCLIB identity, and require `printable?` before matching. This instantiates R6 and R7.
- KTD5. **Treat a zero-match refresh as unsafe.** A structurally valid Apple response that produces no confident LRCLIB matches does not replace a prior list. A successful refresh may publish 1-20 matches after exhausting all 25 candidates, but zero indicates likely upstream or matcher drift and exits nonzero with the last snapshot intact. This is a fail-safe interpretation of R2, R6, and R8.
- KTD6. **Show Popular Now only on archive page one.** `/songs` page one renders the ranked section followed by archive page one; later pagination pages render only the alphabetical archive. Current songs are excluded before archive counting and pagination, so no song is duplicated and sitemap pagination reflects the archive projection. This instantiates R1-R4 and R14.
- KTD7. **Carry catalog origin with an allowlisted query parameter.** Links from `/songs` append `entry=popular` or `entry=archive`; the song page accepts only those two values and otherwise treats the visit as direct. The load form exposes that value to the Stimulus controller, which emits `Song Lyrics Load Started` with only `entry_method`. Canonical URLs omit the query string. This instantiates R18-R20 without storing or transmitting song metadata.
- KTD8. **Schedule outside the Rails process.** Follow the existing Kamal-alias plus host-scheduler pattern rather than adding a queue backend the repository does not use. Add a `refresh_popular` deployment alias, document Monday 09:00 UTC as the default weekly run, require non-overlap and retained output, and make the task idempotent for manual retry. This instantiates R5, R8, and R9.

### High-Level Technical Design

```mermaid
flowchart TB
  Scheduler[Weekly host scheduler] --> Task[songs:refresh_popular]
  Task --> Apple[Apple top 25 JSON feed]
  Apple --> Validate[Validate and rank candidates]
  Validate --> LRCLIB[Bounded LRCLIB searches]
  LRCLIB --> Match[Strict title and artist matcher]
  Match --> Proposed[Complete proposed list: 1 to 20]
  Proposed --> Tx[Atomic Song rank reconciliation]
  Tx --> Current[/songs Popular Now]
  Tx --> Archive[/songs alphabetical archive]
  Current --> Page[Metadata-only song page]
  Archive --> Page
  Page --> Load[Explicit lyric load and analytics event]
```

External requests happen before the transaction. The transaction is intentionally small: upsert matched `Song` metadata by LRCLIB `source_id`, make new matches indexable, clear old current ranks, then assign rank, Apple identity, Apple URL, and the same successful refresh timestamp. A departed song retains all page metadata and `indexable_at`; only its popularity fields are cleared.

### Data and Interface Contracts

- `songs.apple_music_id`: nullable string because the feed is an external identifier and should not be coerced to application identity.
- `songs.apple_music_url`: nullable bounded string containing only a validated HTTPS Apple destination.
- `songs.popular_rank`: nullable integer constrained by model validation to 1-20 and protected by a unique partial database index while non-null.
- `songs.popular_refreshed_at`: nullable datetime shared across every row in the current successful snapshot; `/songs` displays the maximum current value as the refresh date.
- Apple feed parsing accepts a JSON object with `feed.results`; each of the returned candidates requires a positive/string identifier, nonblank `name` and `artistName`, and an HTTPS `url` whose host is exactly `music.apple.com`. Unknown fields are ignored, but any malformed candidate or invalid top-level response raises a service error so a damaged response cannot publish a partial replacement.
- The refresh result reports candidate, matched, skipped, and published counts. It never logs song titles, lyrics, or LRCLIB lyric content.

### Implementation Constraints

- Do not persist lyrics during refresh; persist only LRCLIB and Apple metadata needed by existing public pages and attribution links.
- Do not reuse `Song#promote!`; popularity admission makes a verified match immediately indexable without incrementing organic print demand.
- Preserve immutable source-ID slugs and all existing organic promotion behavior.
- Use Faraday's existing adapter, timeouts, JSON parsing, and service-error conventions; no new gem or API credential is required.
- Keep Apple links visually subordinate to the PrintLyrics song-page link and label them clearly so the catalog's primary action remains the printing workflow.
- Keep the existing verifier authoritative for later LRCLIB availability loss. Its not-found path must also remove current popularity through `Song.indexable` filtering; the rank may remain stored for audit but must never render while unavailable.
- All indexable GET responses remain lyric-free, and no new public route is introduced.

### Sequencing

1. Land persistence and pure HTTP/matching contracts so refresh behavior can be unit tested without rendering UI.
2. Land the atomic refresh service and task, proving failure preservation and idempotency before any page consumes popularity state.
3. Rework catalog projections, rendering, sitemap counts, and attribution using the persisted contract.
4. Add low-cardinality load-origin analytics and update operational documentation.
5. Run focused, full, system, style, security, and browser gates before rollout; run the first production refresh before relying on the Popular Now presentation.

### Risks and Mitigations

- **Apple feed shape or availability changes:** Strict top-level validation, explicit service errors, and pre-transaction work preserve the prior snapshot.
- **False LRCLIB matches:** Exact normalized title and artist comparison, ambiguity rejection, and no version-suffix stripping favor a shorter but trustworthy list.
- **Database uniqueness conflicts during replacement:** Clear old ranks and assign the proposed order inside one transaction; the partial unique index catches invariant drift.
- **A small valid list creates weak presentation:** Render “up to 20,” keep the archive useful immediately below it, and treat zero as a failed refresh.
- **Apple terms change:** Attribution and feed-supplied destinations are visible; the site owner must pause the schedule if the accepted operating assumption changes.
- **Analytics cardinality or privacy leakage:** Only an allowlisted `popular`, `archive`, or `direct` value leaves the browser; integration and JavaScript tests assert no metadata properties.
- **Concurrent refreshes:** The host scheduler must prevent overlap; the transaction and unique rank index keep database state coherent if an accidental overlap reaches reconciliation.

---

## Implementation Units

### U1. Persist and parse popularity candidates

- **Goal:** Establish the bounded data and Apple HTTP contracts without altering current catalog behavior.
- **Requirements:** R2, R5, R6, R8, R9, R21.
- **Files:** `db/migrate/*_add_popularity_to_songs.rb`, `db/schema.rb`, `app/models/song.rb`, `app/models/apple_song_candidate.rb`, `app/services/apple_top_songs_client.rb`, `test/models/song_test.rb`, `test/models/apple_song_candidate_test.rb`, `test/services/apple_top_songs_client_test.rb`.
- **Patterns:** Follow `app/services/lrc_lib_client.rb` for injected Faraday connections, bounded timeouts, headers, JSON parsing, and narrow service errors; follow existing `Song` validation and scopes.
- **Approach:** Add nullable popularity columns and indexes; expose ordered `Song.popular` and archive scopes; model one validated feed candidate as a value object; parse only the selected US top-25 endpoint and reject malformed top-level responses.
- **Test scenarios:**
  1. A valid Apple payload yields ranked candidates with identifier, title, artist, and HTTPS Apple destination in source order.
  2. HTTP errors, timeouts, invalid JSON, or a missing/non-array `feed.results` raise the client service error.
  3. A malformed individual candidate rejects the response and preserves the previously published snapshot.
  4. Song validation rejects ranks outside 1-20 and duplicate non-null ranks at the database boundary while permitting many null ranks.
  5. Popular and archive scopes exclude unavailable/unindexed rows and order deterministically.
- **Verification:** `bin/rails test test/models/song_test.rb test/models/apple_song_candidate_test.rb test/services/apple_top_songs_client_test.rb`.
- **Dependencies:** None.

### U2. Match and atomically refresh the chart

- **Goal:** Produce an idempotent, fail-closed weekly reconciliation from Apple candidates to verified LRCLIB songs.
- **Requirements:** R6-R13, R16, R17.
- **Files:** `app/services/lrc_lib_client.rb`, `app/services/popular_song_matcher.rb`, `app/services/popular_song_catalog_refresh.rb`, `lib/tasks/songs.rake`, `config/deploy.yml`, `test/services/lrc_lib_client_test.rb`, `test/services/popular_song_matcher_test.rb`, `test/services/popular_song_catalog_refresh_test.rb`, `test/tasks/songs_task_test.rb`.
- **Patterns:** Follow `SongCatalogVerifier` for result counters and distinct not-found/service-failure semantics; use dependency injection for both clients so external behavior is deterministic in tests.
- **Approach:** Add a bounded catalog-search method; implement the KTD3 exact matcher; collect up to 20 matches from 25 candidates; abort on any external service failure or zero total matches; reconcile all current ranks in one transaction while preserving URLs and index eligibility; expose the operation through `songs:refresh_popular` and a Kamal alias.
- **Test scenarios:**
  1. Higher-ranked unmatched and ambiguous candidates are skipped and later exact matches fill the list in Apple order.
  2. Featured-artist punctuation/case differences normalize safely, while remix/live/remastered title differences do not collapse.
  3. A new match creates one immediately indexable metadata-only Song with a stable LRCLIB source-ID slug and Apple fields.
  4. A persistent match keeps its slug and moves to its new rank; a departed match loses popularity only and remains indexable.
  5. Repeating the same refresh makes no duplicate songs and leaves the same ordered membership.
  6. Apple failure, LRCLIB service failure, invalid feed, and zero matches all leave membership and the previous refresh timestamp unchanged.
  7. A successful short list of 1-19 unique matches atomically replaces the prior list.
  8. The rake task prints bounded counters, exits nonzero on refresh failure, and the deployment alias invokes it without credentials.
- **Verification:** `bin/rails test test/services/lrc_lib_client_test.rb test/services/popular_song_matcher_test.rb test/services/popular_song_catalog_refresh_test.rb test/tasks/songs_task_test.rb`.
- **Dependencies:** U1.

### U3. Rework `/songs` and sitemap projections

- **Goal:** Make `/songs` the canonical current-plus-archive catalog while preserving lyric-free song pages and crawlability.
- **Requirements:** R1-R4, R9-R17, R21.
- **Files:** `app/controllers/songs_controller.rb`, `app/controllers/sitemaps_controller.rb`, `app/views/songs/index.html.erb`, `config/locales/en.yml`, `app/assets/tailwind/application.css`, `test/integration/songs_flow_test.rb`, `test/integration/sitemap_test.rb`.
- **Patterns:** Preserve the current controller pagination, canonical metadata, crawlable anchor markup, and `Song.indexable` boundary; extend the existing catalog visual language rather than creating a second page shell.
- **Approach:** On page one, query ranked eligible songs separately and paginate only the remaining archive scope. Render semantic section headings, ordered rank context, a machine-readable refresh date, primary PrintLyrics page links, and secondary Apple destinations with accessible names that distinguish them from the PrintLyrics links. On later pages omit Popular Now. Base sitemap archive-page counts on the archive projection and continue emitting every eligible Song URL exactly once.
- **Test scenarios:**
  1. Page one renders Popular Now before the archive, in rank order, with US/Apple attribution, last refresh date, and an Apple destination per current song.
  2. Current songs do not appear in archive results; former current, organic, and legacy songs do.
  3. Page two omits Popular Now and paginates the archive with correct canonical, previous, and next links.
  4. Empty-current and empty-archive combinations remain useful and do not emit misleading refresh or pagination text.
  5. Unavailable or non-indexable songs appear in neither section; GET responses contain no lyric content.
  6. Sitemap browse pagination matches the archive page count and song URLs remain unique and limited to eligible pages.
  7. Popularity-only rank changes do not create or expose alternate song URLs.
- **Verification:** `bin/rails test test/integration/songs_flow_test.rb test/integration/sitemap_test.rb`.
- **Dependencies:** U1, U2.

### U4. Measure qualified catalog acquisition

- **Goal:** Record lyric-load intent by catalog section without collecting song-level data.
- **Requirements:** R18-R20.
- **Files:** `app/controllers/songs_controller.rb`, `app/views/songs/index.html.erb`, `app/views/songs/show.html.erb`, `app/javascript/controllers/song_load_controller.js`, `test/integration/songs_flow_test.rb`, `test/system/organic_conversion_test.rb`.
- **Patterns:** Import `trackEvent` from `app/javascript/lib/analytics.js`; match the allowlist discipline used for campaign properties.
- **Approach:** Add allowlisted `entry` query values to catalog links, carry the accepted value as a Stimulus value, and emit `Song Lyrics Load Started` at submit start with `entry_method` set to `popular`, `archive`, or `direct`. Keep canonicals free of query parameters and do not alter the POST contract.
- **Test scenarios:**
  1. Popular and archive links carry only their expected low-cardinality origin.
  2. Recognized origin reaches the load controller and emits one event at submit start.
  3. Missing or arbitrary origin maps to `direct` and never becomes an analytics property value.
  4. Event payload contains no title, artist, source ID, Apple ID, token, or lyric content.
  5. Load button busy-state behavior and successful lyric workflow remain unchanged.
- **Verification:** `bin/rails test test/integration/songs_flow_test.rb test/system/organic_conversion_test.rb` plus browser inspection of the Plausible request payload.
- **Dependencies:** U3.

### U5. Document and verify weekly operation

- **Goal:** Make first refresh, scheduling, monitoring, and recovery explicit for the site owner.
- **Requirements:** R5, R8-R13, R18-R21.
- **Files:** `docs/organic-search-operations.md`, `README.md` if its operations index needs an entry.
- **Patterns:** Extend the existing catalog-verifier runbook with exact command, cadence, output, failure preservation, retry, and privacy checks.
- **Approach:** Document the `bin/kamal refresh_popular` production command, Monday 09:00 UTC default, non-overlap requirement, expected counters, first-run ordering, rollback by pausing the schedule, Apple/LRCLIB recovery behavior, Apple attribution review, and the new Plausible goal and segments.
- **Test scenarios:**
  1. A first-run checklist places migration before refresh and refresh before relying on the current section.
  2. Failure guidance never tells the operator to clear prior ranks or bulk-demote pages.
  3. Analytics setup names the exact event and only three accepted `entry_method` values.
  4. Monitoring includes Apple feed health, matched-count drift, last successful refresh date, LRCLIB verifier health, Search Console, and qualified-load conversion.
- **Verification:** Review commands, event names, and accepted values against implementation; run markdown/link checks if the repository provides them.
- **Dependencies:** U2, U3, U4.

---

## Verification Contract

| Gate | Command or check | Proves |
| --- | --- | --- |
| Focused model/client/service | `bin/rails test test/models/song_test.rb test/models/apple_song_candidate_test.rb test/services/apple_top_songs_client_test.rb test/services/lrc_lib_client_test.rb test/services/popular_song_matcher_test.rb test/services/popular_song_catalog_refresh_test.rb` | Feed validation, strict matching, data invariants, atomic refresh, and failure preservation |
| Focused web/task | `bin/rails test test/integration/songs_flow_test.rb test/integration/sitemap_test.rb test/tasks/songs_task_test.rb` | Catalog hierarchy, attribution, canonical/pagination behavior, sitemap projection, and task contract |
| Full Rails | `bin/rails test` | Application regression coverage |
| Browser/system | `bin/rails test:system` | Existing print flow plus catalog-origin behavior in a real browser |
| Style | `bin/rubocop` | Repository Ruby style |
| Dependency audit | `bin/bundler-audit` | Known dependency vulnerabilities |
| Static security | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | Rails security regressions |
| Integrated CI | `bin/ci` | Repository-standard aggregate gate |
| Browser acceptance | Visit page-one and page-two `/songs`, one Popular Now page, and one archive page; inspect HTML and the lyric-load network event | Visual hierarchy, responsive interaction, no lyrics in GET HTML, correct Apple destinations, canonical query stripping, and privacy-safe analytics |
| Production smoke | Run `bin/kamal refresh_popular`, inspect counters and `/songs`, then confirm the scheduler's next run | External feed compatibility and operational readiness |

No live Apple or LRCLIB call is part of the deterministic test suite. HTTP adapters are stubbed; production smoke testing owns real-provider compatibility.

---

## Definition of Done

- U1-U5 satisfy every listed test scenario and their dependency order.
- R1-R21 each trace to at least one implemented unit and verified behavior.
- A valid refresh publishes at most 20 uniquely ranked, printable songs; invalid, failed, or zero-match refreshes preserve the prior list and date.
- Current songs render once, archive pagination remains crawlable, eligible song URLs remain stable, and unavailable/non-indexable songs stay out of browse and sitemap output.
- `/songs` and song GET responses contain no lyrics; the existing POST load remains the only catalog path into editable lyrics.
- Apple attribution and feed-supplied destinations appear for every rendered Popular Now item under the accepted operating assumption.
- `Song Lyrics Load Started` is measurable as `popular`, `archive`, or `direct` with no song, lyric, or token metadata.
- The migration is reversible, new indexes are present in `db/schema.rb`, and existing seeded/organic rows remain eligible after deployment.
- The operations runbook documents first run, weekly non-overlapping scheduling, monitoring, retry, rollback, and analytics setup.
- All Verification Contract gates applicable before deployment pass; production-only smoke checks are clearly handed to the site owner.
- Abandoned experiments, unused abstractions, debug output, generated artifacts, and unrelated user changes are absent from the final diff.
