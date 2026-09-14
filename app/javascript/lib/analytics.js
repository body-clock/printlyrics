const TOKEN_PATH = /^\/lyrics\/[^/]+$/
const GENERATED_KEY_PREFIX = "printlyrics:generated:"
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

export function trackGeneratedPage() {
  const pageKey = document.body.dataset.generatedPageKey
  if (!pageKey) return

  const storageKey = `${GENERATED_KEY_PREFIX}${pageKey}`
  if (sessionStorage.getItem(storageKey)) return

  sessionStorage.setItem(storageKey, "1")
  trackEvent("Print Page Generated")
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
