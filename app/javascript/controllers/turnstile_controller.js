import { Controller } from "@hotwired/stimulus"

// Renders the Turnstile widget for each element that asks for one. The prompt on
// the search-results panel arrives in a Turbo frame update, so the widget is
// rendered per connected element rather than by the API script's own scan of the
// page at load.
//
// If the script never loads, the form still submits without a token, and the
// server refuses a submission it cannot verify. That is the safe direction.
const API_TIMEOUT_MS = 10000
const POLL_INTERVAL_MS = 100

export default class extends Controller {
  static values = { siteKey: String, action: String }

  connect() {
    this.beforeCache = () => this.reset()
    document.addEventListener("turbo:before-cache", this.beforeCache)

    this.pollForApi()
  }

  disconnect() {
    clearInterval(this.timer)
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }

  pollForApi() {
    if (window.turnstile) {
      this.renderWidget()
      return
    }

    const startedAt = Date.now()
    this.timer = setInterval(() => {
      if (window.turnstile) {
        clearInterval(this.timer)
        this.renderWidget()
      } else if (Date.now() - startedAt > API_TIMEOUT_MS) {
        clearInterval(this.timer)
      }
    }, POLL_INTERVAL_MS)
  }

  renderWidget() {
    if (this.widgetId) return

    this.widgetId = window.turnstile.render(this.element, {
      sitekey: this.siteKeyValue,
      action: this.actionValue
    })
  }

  // A cached page must not keep a widget whose token has already been spent, so
  // the widget is removed before Turbo stores the snapshot and rendered again
  // when the page comes back.
  reset() {
    if (!this.widgetId) return

    window.turnstile?.remove(this.widgetId)
    this.widgetId = null
  }
}
