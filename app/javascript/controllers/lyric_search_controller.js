import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["query", "panel", "idleLabel", "busyLabel"]

  start(event) {
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
