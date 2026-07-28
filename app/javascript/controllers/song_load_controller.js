import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "idleLabel", "busyLabel"]

  start() {
    this.buttonTarget.disabled = true
    this.element.setAttribute("aria-busy", "true")
    this.idleLabelTarget.hidden = true
    this.busyLabelTarget.hidden = false
  }

  finish() {
    this.buttonTarget.disabled = false
    this.element.setAttribute("aria-busy", "false")
    this.idleLabelTarget.hidden = false
    this.busyLabelTarget.hidden = true
  }
}
