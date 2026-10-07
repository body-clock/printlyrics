import { sessionStore } from "lib/settings_store"
import { rememberCreatedSongbook, rememberReportedOffer, rememberReportedSheet } from "lib/reported_events"

// The trailing slash is optional because Rails serves `/lyrics/<token>/` as the
// same page, and a shared link that gained one would otherwise report the real
// token to every destination.
const TOKEN_PATHS = /^\/(lyrics|songbooks)\/[^/]+\/?$/
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

// A form that names the event it reports, declared in the view beside the
// surface it belongs to. The manual-entry form posts a whole page, so its
// attempt has to be reported on submit rather than by the page that follows it.
export function trackSubmittedEvent(form) {
  const name = form.dataset?.analyticsSubmit
  if (name) trackEvent(name)

  // A second name a form may carry when only this site's own service is to
  // receive it — the offer's dismissal. It is declared in the same place and
  // read here rather than at the control, so a form has one place to look.
  const umamiOnly = form.dataset?.analyticsUmamiSubmit
  if (umamiOnly) trackUmamiEvent(umamiOnly)
}

// An outcome the server rendered into a whole page rather than into a frame: the
// songbook offer, which is in the markup every tab and every restored page
// carries. It is reported on the load that follows the response, and the
// response names itself so a snapshot the browser replays — the same markup,
// the same key — cannot report the same offer twice.
//
// The offer renders in two places — the sheet that crossed two, and the entry
// panel the visit comes back to for the next one — and both report the one
// name, so the reading that separates them travels with it: the marker names
// its own surface, and the count is the visit's, the same bucket the sheet
// events carry.
export function trackPageResponses(root) {
  root.querySelectorAll("[data-analytics-page-response]").forEach((marker) => {
    const responseKey = marker.dataset.analyticsResponseKey
    if (responseKey && !rememberReportedOffer(responseKey)) return

    const surface = marker.dataset.analyticsOfferSurface
    trackUmamiEvent(marker.dataset.analyticsPageResponse, {
      ...sessionPageCountProperties(),
      ...(surface && { songbook_offer_surface: surface })
    })
  })
}

// An event this site's own service is the only destination for. Umami reads the
// properties these exist for and Plausible's plan cannot, so they would be a
// goal whose answer is invisible there; the goal list stays short on purpose.
// None of these payloads carries a visitor's own words.
export function trackUmamiEvent(name, props = {}) {
  sendToUmami(name, props)
}

// An outcome the server knows and the client cannot: the marker is rendered
// with the response that carries it. A Turbo frame render never fires
// `turbo:load`, which is what reports the body markers below, and a snapshot
// restored from Turbo's cache by the Back button never fires
// `turbo:frame-load`, so a restored panel cannot report it twice.
export function trackResponseEvents(root) {
  root.querySelectorAll("[data-analytics-response]").forEach((marker) => {
    trackEvent(marker.dataset.analyticsResponse)
  })
}

// Each distinct print page is counted once per visit. The count itself is the
// server's, rendered from the visit it holds in the session, so this only keeps
// a replay of the same response from reporting the sheet twice.
export function trackGeneratedPage() {
  const pageKey = document.body.dataset.generatedPageKey
  if (!pageKey || !rememberReportedSheet(pageKey)) return

  const count = visitSheetCount()
  trackEvent("Print Page Generated", sessionPageCountProperties(count))
  // The visit's second sheet, in whichever tab made it: this is the moment the
  // sitting turned into a packet.
  if (count === 2) trackEvent("Second Print Page Generated")
}

// A songbook is only a set once it holds more than one song. The server decides
// that threshold and renders this marker on the visit that crossed it, so the
// event reports a set coming into being rather than every later visit to it. The
// origin says which route started it: the offer, or a song added to a set.
//
// The route is also its own event, because Plausible's plan has no custom
// properties: `songbook_origin` cannot be read from its dashboard, so the offer
// only stays visible there as a goal. Umami reads the parameter directly. While
// both run, `Songbook Created` is the total and `Songbook Created From Offer` is
// the subset the nudge produced, so the offer's conversion rate is one over the
// other in either one.
export function trackCreatedSongbook() {
  const { createdSongbookSize, createdSongbookOrigin, createdSongbookToken } = document.body.dataset
  if (!createdSongbookSize) return

  // The marker rides in the markup, so a snapshot restored from Turbo's cache
  // carries it back in and would report the same set again. Claiming the set
  // first is what keeps it one report per session, the way the sheet counter
  // keeps `Print Page Generated` one per session.
  if (!rememberCreatedSongbook(createdSongbookToken)) return

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
// running count at the moment the event fired, not a final visit total.
export function sessionPageCountProperties(count = visitSheetCount()) {
  return { page_count_in_session: pageCountBucket(count) }
}

// The visit's running total, rendered by the server with the rest of the page:
// the visit is a browser session, so its count is the same in every tab and
// survives navigation within it.
function visitSheetCount() {
  return Number(document.body.dataset.visitSheetCount || 0)
}

function pageCountBucket(count) {
  if (count <= 1) return "1"
  if (count === 2) return "2"
  if (count <= 5) return "3-5"
  return "6+"
}

// Both destinations run side by side until the cutover, and a browser that
// blocks one still reports the other. Telemetry never interrupts a product
// action: unavailable storage or a throwing third-party stub must not stop the
// print dialog from opening.
function dispatch(name, props = {}) {
  const location = analyticsUrl()
  const eventProps = { ...campaignProps(), ...props }

  sendToPlausible(name, location, eventProps)
  sendToUmami(name, eventProps)
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

// Umami fills url, title, and referrer from the document on every payload,
// custom events included, so a saved page would report its token and its song
// title unless each payload supplies its own. The tracker's function form is the
// only shape that can replace them, and it is how an event carries properties as
// well: a name plus `data`. Umami keeps the product's event names verbatim,
// spaces and all, so the names below are the names the dashboard lists.
//
// A pageview carries no data of its own; campaign attribution comes from the
// landing URL's UTM parameters, which Umami attributes natively, the same way
// Plausible does.
function sendToUmami(name, props) {
  if (typeof window.umami?.track !== "function") return

  try {
    window.umami.track((payload) => ({
      ...payload,
      url: analyticsUrl(),
      title: analyticsTitle(),
      referrer: analyticsReferrer() || "",
      ...(name === "pageview" ? {} : { name, data: props })
    }))
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
