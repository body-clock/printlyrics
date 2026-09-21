import { sessionStore } from "lib/settings_store"

const SESSION_PAGES_KEY = "printlyrics:session-pages"

// The distinct print pages this tab has generated, in generation order. Order is
// what a songbook needs and membership is what keeps a restored page from being
// counted twice, so one ordered list serves both. It lives in session storage,
// which is per tab: a set of sheets belongs to one sitting, not to one browser.
// A stored value in an older format reads as an empty list.
export function sessionPages() {
  try {
    const parsed = JSON.parse(sessionStore().get(SESSION_PAGES_KEY) || "[]")
    return Array.isArray(parsed) ? parsed.filter((token) => typeof token === "string") : []
  } catch {
    return []
  }
}

// Returns the updated list, or null when this page was already counted.
export function rememberSessionPage(pageKey) {
  if (!pageKey) return null

  const pages = sessionPages()
  if (pages.includes(pageKey)) return null

  const next = [...pages, pageKey]
  sessionStore().set(SESSION_PAGES_KEY, JSON.stringify(next))
  return next
}

// The page that just loaded may not be recorded yet: the preview reads this
// before the analytics listener runs. Folding its marker in makes the list the
// same whichever order the two run in.
export function sessionPagesWith(pageKey) {
  const pages = sessionPages()
  if (!pageKey || pages.includes(pageKey)) return pages

  return [...pages, pageKey]
}
