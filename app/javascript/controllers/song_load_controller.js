import { Controller } from "@hotwired/stimulus"
import { trackEvent } from "lib/analytics"

export default class extends Controller {
  static targets = ["button", "idleLabel", "busyLabel"]
  static values = { entry: String }

  start() {
    trackEvent("Song Lyrics Load Started", { entry_method: this.allowedEntryMethod })
    this.buttonTarget.disabled = true
    this.element.setAttribute("aria-busy", "true")
    this.idleLabelTarget.hidden = true
    this.busyLabelTarget.hidden = false
  }

  get allowedEntryMethod() {
    return ["popular", "archive"].includes(this.entryValue) ? this.entryValue : "direct"
  }

  finish() {
    this.buttonTarget.disabled = false
    this.element.setAttribute("aria-busy", "false")
    this.idleLabelTarget.hidden = false
    this.busyLabelTarget.hidden = true
  }
}
