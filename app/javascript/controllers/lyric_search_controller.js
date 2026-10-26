import { Controller } from "@hotwired/stimulus"

const MINIMUM_SELECTION_FEEDBACK_MS = 400

export default class extends Controller {
  static targets = [
    "query",
    "panel",
    "idleLabel",
    "busyLabel",
    "resultButton",
    "resultIdle",
    "resultBusy",
    "transportError"
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
    this.transportErrorTarget.hidden = true
    event.currentTarget.setAttribute("aria-busy", "true")
    this.idleLabelTarget.hidden = true
    this.busyLabelTarget.hidden = false
    this.hideResults()
  }

  finish(event) {
    event.currentTarget.setAttribute("aria-busy", "false")
    this.idleLabelTarget.hidden = false
    this.busyLabelTarget.hidden = true
    if (!event.detail.fetchResponse) {
      this.transportErrorTarget.hidden = false
      if (this.hasPanelTarget) this.panelTarget.hidden = false
    }
  }

  selecting(event) {
    const form = event.currentTarget
    this.transportErrorTarget.hidden = true
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
    if (event.detail.success) return

    if (!event.detail.fetchResponse) this.transportErrorTarget.hidden = false
    this.resetResultState(event.currentTarget)
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


  hideResults() {
    if (this.hasPanelTarget) this.panelTarget.hidden = true
  }

  toggleResultState(form, loading) {
    form.querySelectorAll('[data-lyric-search-target~="resultIdle"]').forEach((element) => {
      element.hidden = loading
    })
    const busy = form.querySelector('[data-lyric-search-target~="resultBusy"]')
    if (busy) busy.hidden = !loading
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
