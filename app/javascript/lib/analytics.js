const TOKEN_PATH = /^\/lyrics\/[^/]+$/
const GENERATED_KEY_PREFIX = "printlyrics:generated:"
const SESSION_PAGE_COUNT_KEY = "printlyrics:session-pages"
const CAMPAIGN_KEY = "printlyrics:campaign"

// Campaign values are allowlisted by the server (AnalyticsCampaigns) and read
// from a data attribute, so there is one definition instead of a parallel list
// in this file that can drift from the documented operator contract.
let campaignAllowlist

export function analyticsUrl() {
  const url = new URL(window.location.href)
  if (!TOKEN_PATH.test(url.pathname)) return url.toString()

  url.pathname = "/lyrics/:token"
  url.search = ""
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
  const pageKey = document.body.dataset.generatedPageKey
  if (!pageKey) return

  const storageKey = `${GENERATED_KEY_PREFIX}${pageKey}`
  if (sessionStorage.getItem(storageKey)) return

  sessionStorage.setItem(storageKey, "1")
  const count = bumpSessionPageCount()
  trackEvent("Print Page Generated", sessionPageCountProperties(count))
  if (count === 2) trackEvent("Second Print Page Generated")
}

// The bucket, not the raw number, keeps the property low-cardinality. It is a
// running count at the moment the event fired, not a final session total.
export function sessionPageCountProperties(count = sessionPageCount()) {
  return { page_count_in_session: pageCountBucket(count) }
}

function sessionPageCount() {
  try {
    return Number(sessionStorage.getItem(SESSION_PAGE_COUNT_KEY)) || 0
  } catch {
    return 0
  }
}

function bumpSessionPageCount() {
  const next = sessionPageCount() + 1
  try {
    sessionStorage.setItem(SESSION_PAGE_COUNT_KEY, String(next))
  } catch {
    // Degraded mode — the count stalls, but events still report.
  }
  return next
}

function pageCountBucket(count) {
  if (count <= 1) return "1"
  if (count === 2) return "2"
  if (count <= 5) return "3-5"
  return "6+"
}

function dispatch(name, props = {}) {
  if (typeof window.plausible !== "function") return

  const options = { url: analyticsUrl() }
  const eventProps = { ...campaignProps(), ...props }
  if (Object.keys(eventProps).length > 0) options.props = eventProps
  window.plausible(name, options)
}

export function captureCampaign() {
  const params = new URLSearchParams(window.location.search)
  const { sources, campaigns } = campaignValues()
  const source = allowedValue(params.get("utm_source"), sources)
  const campaign = allowedValue(params.get("utm_campaign"), campaigns)
  if (!source && !campaign) return

  sessionStorage.setItem(CAMPAIGN_KEY, JSON.stringify({
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
  try {
    return JSON.parse(sessionStorage.getItem(CAMPAIGN_KEY)) || {}
  } catch {
    sessionStorage.removeItem(CAMPAIGN_KEY)
    return {}
  }
}

function allowedValue(value, allowlist) {
  const normalized = value?.trim().toLowerCase()
  return allowlist.has(normalized) ? normalized : null
}
