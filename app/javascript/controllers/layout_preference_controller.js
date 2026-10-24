import { Controller } from "@hotwired/stimulus"
import { SettingsStore } from "lib/settings_store"

const SIZE_KEY = "printlyrics-size"
const COLUMNS_KEY = "printlyrics-columns"
const SIZES = ["s", "m", "l", "xl"]

// A sheet's size and columns live in storage, not on the server. The form that
// turns sheets into a songbook carries them into the new entries, so the sheet
// the visitor just formatted does not jump back to the defaults when it becomes
// part of a set.
export default class extends Controller {
  connect() {
    this.settings = new SettingsStore()
    this.sync = this.sync.bind(this)
    this.element.addEventListener("submit", this.sync)
    this.sync()
  }

  disconnect() {
    this.element.removeEventListener("submit", this.sync)
  }

  // Read at submit time as well as on connect: the preview controls may have
  // changed storage since this form rendered.
  sync() {
    const size = this.settings.get(SIZE_KEY, "m")
    const columns = this.settings.get(COLUMNS_KEY, "1")
    this.setInput("size", SIZES.includes(size) ? size : "m")
    this.setInput("columns", columns === "2" ? "2" : "1")
  }

  setInput(name, value) {
    const input = this.element.querySelector(`input[name="${name}"]`)
    if (input) input.value = value
  }
}
