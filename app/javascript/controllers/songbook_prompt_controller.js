import { Controller } from "@hotwired/stimulus"
import { sessionStore } from "lib/settings_store"
import { sessionPagesWith } from "lib/session_pages"

const DISMISSED_KEY = "printlyrics:songbook-prompt-dismissed"

// A second sheet is the moment a visit turns into a set, so this offers to
// gather the sheets already made instead of waiting for the visitor to work out
// what the songbook control does. It stays hidden unless that is true, and one
// answer — either way — silences it for the rest of the tab.
export default class extends Controller {
  static targets = ["message", "form"]

  connect() {
    if (sessionStore().get(DISMISSED_KEY)) return

    const pages = sessionPagesWith(document.body.dataset.generatedPageKey)
    if (pages.length < 2) return

    this.messageTarget.textContent =
      this.messageTarget.dataset.template.replace("%{count}", pages.length)
    pages.forEach((token) => this.formTarget.append(this.hiddenField(token)))
    this.element.hidden = false
  }

  // Accepting is the same signal as declining: this tab now knows what a
  // songbook is, so a later generation must not ask again.
  accept() {
    this.silence()
  }

  dismiss() {
    this.silence()
    this.element.hidden = true
  }

  silence() {
    sessionStore().set(DISMISSED_KEY, "1")
  }

  hiddenField(token) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = "lyric_tokens[]"
    input.value = token
    return input
  }
}
