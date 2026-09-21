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
export function analyticsUrl() {
  const url = new URL(window.location.href)
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

// Telemetry never interrupts a product action: unavailable storage or a
// throwing third-party stub must not stop the print dialog from opening.
function dispatch(name, props = {}) {
  if (typeof window.plausible !== "function") return

  try {
    const options = { url: analyticsUrl() }
    const eventProps = { ...campaignProps(), ...props }
    if (Object.keys(eventProps).length > 0) options.props = eventProps
    window.plausible(name, options)
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
