import { Controller } from "@hotwired/stimulus"
import { trackEvent } from "lib/analytics"

export default class extends Controller {
  static targets = ["query", "panel", "idleLabel", "busyLabel"]

  start(event) {
    trackEvent("Song Search Submitted", { entry_method: "search" })
    event.currentTarget.setAttribute("aria-busy", "true")
    this.idleLabelTarget.hidden = true
    this.busyLabelTarget.hidden = false
    this.hideResults()
  }

  finish(event) {
    event.currentTarget.setAttribute("aria-busy", "false")
    this.idleLabelTarget.hidden = false
    this.busyLabelTarget.hidden = true
  }

  selected(event) {
    if (event.detail.success) {
      trackEvent("Song Selected", { entry_method: "search" })
    }
  }

  close(event) {
    if (!this.hasPanelTarget || this.panelTarget.hidden) return

    event?.preventDefault()
    this.hideResults()
    this.queryTarget.focus()
  }

  dismissFromOutside(event) {
    if (!this.hasPanelTarget || this.panelTarget.hidden || this.element.contains(event.target)) return

    this.hideResults()
  }

  hideResults() {
    if (this.hasPanelTarget) this.panelTarget.hidden = true
  }
}
