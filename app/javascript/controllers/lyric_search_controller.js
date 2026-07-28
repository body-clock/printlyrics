import { Controller } from "@hotwired/stimulus"
import { trackEvent } from "lib/analytics"

const MINIMUM_SELECTION_FEEDBACK_MS = 400

export default class extends Controller {
  static targets = [
    "query",
    "panel",
    "idleLabel",
    "busyLabel",
    "resultButton",
    "resultIdle",
    "resultBusy"
  ]

  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.boundDelayRender = this.delayRender.bind(this)
    this.frame.addEventListener("turbo:before-frame-render", this.boundDelayRender)
  }

  disconnect() {
    this.frame.removeEventListener("turbo:before-frame-render", this.boundDelayRender)
  }

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

  selecting(event) {
    const form = event.currentTarget
    const button = form.querySelector('[data-lyric-search-target~="resultButton"]')

    this.selectionStartedAt = performance.now()
    form.setAttribute("aria-busy", "true")
    this.resultButtonTargets.forEach((resultButton) => {
      resultButton.disabled = true
    })
    button.classList.add("is-loading")
    this.toggleResultState(form, true)
  }

  selected(event) {
    if (!event.detail.success) {
      this.resetResultState(event.currentTarget)
      return
    }

    trackEvent("Song Selected", { entry_method: "search" })
  }

  delayRender(event) {
    if (!this.selectionStartedAt) return

    const elapsed = performance.now() - this.selectionStartedAt
    const remaining = MINIMUM_SELECTION_FEEDBACK_MS - elapsed
    if (remaining <= 0) {
      this.selectionStartedAt = null
      return
    }

    event.preventDefault()
    setTimeout(() => {
      this.selectionStartedAt = null
      event.detail.resume()
    }, remaining)
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

  toggleResultState(form, loading) {
    form.querySelectorAll('[data-lyric-search-target~="resultIdle"]').forEach((element) => {
      element.hidden = loading
    })
    form.querySelector('[data-lyric-search-target~="resultBusy"]').hidden = !loading
  }

  resetResultState(form) {
    form.setAttribute("aria-busy", "false")
    this.resultButtonTargets.forEach((button) => {
      button.disabled = false
      button.classList.remove("is-loading")
    })
    this.toggleResultState(form, false)
  }
}
