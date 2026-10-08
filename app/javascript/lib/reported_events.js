import { sessionStore } from "lib/settings_store"

// What this tab has already reported, so a response the browser replays does not
// report it twice. Turbo caches the response it rendered and a restoration puts
// that markup back on the page, which is why membership has to be remembered
// rather than derived from the page.
//
// Each list is its own because each is keyed by a different thing: the sheet the
// visit generated, the response that carried an offer or a feedback prompt, and
// the set that came into being. All three are session storage, which is per tab
// — and the tab is exactly the scope a snapshot can be replayed in. A stored
// value in an older format reads as an empty list.
const REPORTED_SHEETS_KEY = "printlyrics:reported-sheets"
const REPORTED_RESPONSES_KEY = "printlyrics:reported-responses"
const CREATED_SONGBOOKS_KEY = "printlyrics:created-songbooks"

// Whether this sheet still needs its generation reported, so one sheet is
// counted once however many times its page is rendered.
export function rememberReportedSheet(pageKey) {
  return claim(REPORTED_SHEETS_KEY, pageKey)
}

// Whether this response still needs the outcome it carried reported. The key is
// the response itself — the offer's own key, or the sheet a feedback prompt was
// rendered under — and not the outcome's contents: a re-rendered page is a new
// response and a genuinely new showing, a replayed one is neither.
export function rememberReportedResponse(responseKey) {
  return claim(REPORTED_RESPONSES_KEY, responseKey)
}

// Whether this set still needs to be reported. A marker with no token has
// nothing to dedupe on, so it reports.
export function rememberCreatedSongbook(token) {
  return claim(CREATED_SONGBOOKS_KEY, token)
}

function claim(key, value) {
  if (!value) return true

  const seen = claimed(key)
  if (seen.includes(value)) return false

  sessionStore().set(key, JSON.stringify([...seen, value]))
  return true
}

function claimed(key) {
  try {
    const parsed = JSON.parse(sessionStore().get(key) || "[]")
    return Array.isArray(parsed) ? parsed.filter((value) => typeof value === "string") : []
  } catch {
    return []
  }
}
