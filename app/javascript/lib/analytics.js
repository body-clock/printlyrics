import { sessionStore } from "lib/settings_store"
import { rememberSessionPage, sessionPages } from "lib/session_pages"

const TOKEN_PATHS = /^\/(lyrics|songbooks)\/[^/]+$/
const CAMPAIGN_KEY = "printlyrics:campaign"

// Campaign values are allowlisted by the server (AnalyticsCampaigns) and read
// from a data attribute, so there is one definition instead of a parallel list
// in this file that can drift from the documented operator contract.
let campaignAllowlist

// A share token is the only way to reach someone's saved page, so no reported
// location may carry a real one. Paths become the synthetic `:token` form, and
// the songbook context on the entry form keeps its parameter without its value.
// Every analytics destination reports locations through here.
export function analyticsUrl(href = window.location.href) {
  const url = new URL(href)
  const tokenPath = TOKEN_PATHS.exec(url.pathname)

  if (tokenPath) {
    url.pathname = `/${tokenPath[1]}/:token`
    url.search = ""
  } else if (url.searchParams.has("songbook")) {
    url.searchParams.set("songbook", ":token")
  }

  url.hash = ""
  return url.toString()
}

// A saved page's title is the song title and artist, so a redacted location
// reports the synthetic path as its title instead of the document's.
export function analyticsTitle() {
  const { pathname } = new URL(analyticsUrl())
  return TOKEN_PATHS.test(pathname) ? pathname : document.title
}

// The referring page can be a saved page too, so a same-origin referrer is
// redacted the same way every reported location is. External referrers pass
// through: they are the acquisition signal.
export function analyticsReferrer() {
  if (!document.referrer) return null

  return new URL(document.referrer).origin === window.location.origin ?
    analyticsUrl(document.referrer) : document.referrer
}

export function trackPageview() {
  captureCampaign()
  dispatch("pageview")
}

export function trackEvent(name, props = {}) {
  dispatch(name, props)
}

// Each distinct print page is counted once per session. The running total is
// what separates a one-off visitor from someone assembling a packet, which is
// the difference between a utility and a product. Counting happens in session
// storage, so it identifies no one and survives navigation within a visit.
export function trackGeneratedPage() {
  const pages = rememberSessionPage(document.body.dataset.generatedPageKey)
  if (!pages) return

  trackEvent("Print Page Generated", sessionPageCountProperties(pages.length))
  if (pages.length === 2) trackEvent("Second Print Page Generated")
}

// A songbook is only a set once it holds more than one song. The server decides
// that threshold and renders this marker on the visit that crossed it, so the
// event reports a set coming into being rather than every later visit to it. The
// origin says which route started it: the offer, or a song added to a set.
//
// The route is also its own event, because Plausible's plan has no custom
// properties: `songbook_origin` cannot be read from its dashboard, so the offer
// only stays visible there as a goal. GA4 reads the parameter directly. While
// both run, `Songbook Created` is the total and `Songbook Created From Offer` is
// the subset the nudge produced, so the offer's conversion rate is one over the
// other in either one.
export function trackCreatedSongbook() {
  const { createdSongbookSize, createdSongbookOrigin } = document.body.dataset
  if (!createdSongbookSize) return

  trackEvent("Songbook Created", {
    ...songbookSizeProperties(Number(createdSongbookSize)),
    ...(createdSongbookOrigin && { songbook_origin: createdSongbookOrigin })
  })
  if (createdSongbookOrigin === "offer") trackEvent("Songbook Created From Offer")
}

// A printed set is a different act from printing one sheet, and how many songs
// it holds is what separates a rehearsal packet from a classroom handout. Both
// ride on the existing print goal, so the dashboard gains no fourth conversion.
export function songbookSizeProperties(size) {
  return { songbook_size: pageCountBucket(size) }
}

// The bucket, not the raw number, keeps the property low-cardinality. It is a
// running count at the moment the event fired, not a final session total.
export function sessionPageCountProperties(count = sessionPages().length) {
  return { page_count_in_session: pageCountBucket(count) }
}

function pageCountBucket(count) {
  if (count <= 1) return "1"
  if (count === 2) return "2"
  if (count <= 5) return "3-5"
  return "6+"
}

// GA4 accepts no event name with a space in it, so the product names are mapped.
// This table is the contract the runbook's key-event list repeats: a new event
// is added here and registered in the dashboard.
const GA4_EVENT_NAMES = {
  pageview: "page_view",
  "Print Page Generated": "print_page_generated",
  "Second Print Page Generated": "second_print_page_generated",
  "Print Dialog Opened": "print_dialog_opened",
  "Songbook Created": "songbook_created",
  "Songbook Created From Offer": "songbook_created_from_offer",
  "Songbook Printed": "songbook_printed"
}

// An unmapped name still reaches GA4 in the snake_case form it accepts, so new
// instrumentation shows up immediately instead of silently vanishing.
function ga4EventName(name) {
  return GA4_EVENT_NAMES[name] ||
    String(name).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_+|_+$/g, "")
}

// Both destinations run side by side during the dual run, and a browser that
// blocks one still reports the other. Telemetry never interrupts a product
// action: unavailable storage or a throwing third-party stub must not stop the
// print dialog from opening.
function dispatch(name, props = {}) {
  const location = analyticsUrl()
  const eventProps = { ...campaignProps(), ...props }

  sendToPlausible(name, location, eventProps)
  sendToGoogleAnalytics(ga4EventName(name), location, eventProps)
}

function sendToPlausible(name, location, props) {
  if (typeof window.plausible !== "function") return

  try {
    const options = { url: location }
    if (Object.keys(props).length > 0) options.props = props
    window.plausible(name, options)
  } catch {
    // Ignore analytics failures.
  }
}

function sendToGoogleAnalytics(name, location, props) {
  if (typeof window.gtag !== "function") return

  try {
    // gtag.js would otherwise attach the document's own URL, title, and
    // referrer, and on a saved page those carry the token and song metadata.
    // Every value it would fill in is supplied here instead.
    const referrer = analyticsReferrer()
    window.gtag("event", name, {
      page_location: location,
      page_title: analyticsTitle(),
      ...(referrer && { page_referrer: referrer }),
      ...props
    })
  } catch {
    // Ignore analytics failures.
  }
}

export function captureCampaign() {
  const params = new URLSearchParams(window.location.search)
  const { sources, campaigns } = campaignValues()
  const source = allowedValue(params.get("utm_source"), sources)
  const campaign = allowedValue(params.get("utm_campaign"), campaigns)
  if (!source && !campaign) return

  sessionStore().set(CAMPAIGN_KEY, JSON.stringify({
    ...(source && { campaign_source: source }),
    ...(campaign && { campaign_name: campaign })
  }))
}

function campaignValues() {
  if (campaignAllowlist) return campaignAllowlist

  const empty = { sources: new Set(), campaigns: new Set() }
  try {
    const parsed = JSON.parse(document.body.dataset.analyticsCampaigns || "")
    campaignAllowlist = {
      sources: new Set(parsed.sources || []),
      campaigns: new Set(parsed.campaigns || [])
    }
  } catch {
    campaignAllowlist = empty
  }
  return campaignAllowlist
}

function campaignProps() {
  const store = sessionStore()
  try {
    return JSON.parse(store.get(CAMPAIGN_KEY)) || {}
  } catch {
    store.remove(CAMPAIGN_KEY)
    return {}
  }
}

function allowedValue(value, allowlist) {
  const normalized = value?.trim().toLowerCase()
  return allowlist.has(normalized) ? normalized : null
}
