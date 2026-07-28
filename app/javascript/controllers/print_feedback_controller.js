import { Controller } from "@hotwired/stimulus"
import { trackEvent } from "lib/analytics"

const RESPONSE_KEY_PREFIX = "printlyrics:use-case:"

export default class extends Controller {
  static targets = ["question", "thanks"]

  connect() {
    if (sessionStorage.getItem(this.storageKey)) this.showThanks()
  }

  select(event) {
    const useCase = event.currentTarget.dataset.useCase
    if (!useCase || sessionStorage.getItem(this.storageKey)) return

    sessionStorage.setItem(this.storageKey, useCase)
    trackEvent("Print Use Case Selected", { use_case: useCase })
    this.showThanks()
  }

  showThanks() {
    this.questionTarget.hidden = true
    this.thanksTarget.hidden = false
  }

  get storageKey() {
    return `${RESPONSE_KEY_PREFIX}${document.body.dataset.generatedPageKey}`
  }
}
