const TOKEN_PATH = /^\/lyrics\/[^/]+$/
const GENERATED_KEY_PREFIX = "printlyrics:generated:"

export function analyticsUrl() {
  const url = new URL(window.location.href)
  if (!TOKEN_PATH.test(url.pathname)) return url.toString()

  url.pathname = "/lyrics/:token"
  url.search = ""
  url.hash = ""
  return url.toString()
}

export function trackPageview() {
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
  if (Object.keys(props).length > 0) options.props = props
  window.plausible(name, options)
}
