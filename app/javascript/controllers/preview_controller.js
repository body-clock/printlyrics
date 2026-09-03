import { Controller } from "@hotwired/stimulus"
import { trackEvent } from "lib/analytics"
import { SettingsStore } from "lib/settings_store"

const SIZE_KEY = "printlyrics-size"
const COLUMNS_KEY = "printlyrics-columns"

export default class extends Controller {
  static targets = ["pageFrame", "page", "lyrics", "sizeButton", "columnButton"]

  connect() {
    this.settings = new SettingsStore()
    this.setSizeState(this.settings.get(SIZE_KEY, "m"))
    this.setColumnState(this.settings.get(COLUMNS_KEY, "1"))
    this.fitPagePreview()
  }

  setSize(event) {
    const size = event.currentTarget.dataset.size
    this.setSizeState(size)
    this.settings.set(SIZE_KEY, size)
    this.fitPagePreview()
  }

  setColumns(event) {
    const columns = event.currentTarget.dataset.columns
    this.setColumnState(columns)
    this.settings.set(COLUMNS_KEY, columns)
    this.fitPagePreview()
  }

  print() {
    trackEvent("Print Dialog Opened", { entry_method: "print_page" })
    window.print()
  }

  setSizeState(size) {
    this.pageTarget.classList.remove("size-s", "size-m", "size-l", "size-xl")
    this.pageTarget.classList.add(`size-${size}`)
    this.updatePressedState(this.sizeButtonTargets, "size", size)
  }

  setColumnState(columns) {
    this.lyricsTarget.classList.toggle("cols-2", columns === "2")
    this.updatePressedState(this.columnButtonTargets, "columns", columns)
  }

  fitPagePreview() {
    if (window.matchMedia("print").matches) return

    if (!window.matchMedia("(max-width: 700px)").matches) {
      this.pageTarget.style.removeProperty("--preview-scale")
      this.pageFrameTarget.style.removeProperty("height")
      return
    }

    const scale = Math.min(1, this.pageFrameTarget.clientWidth / this.pageTarget.offsetWidth)
    this.pageTarget.style.setProperty("--preview-scale", scale)
    this.pageFrameTarget.style.height = `${this.pageTarget.scrollHeight * scale}px`
  }

  restorePagePreview() {
    window.requestAnimationFrame(() => this.fitPagePreview())
  }

  updatePressedState(buttons, dataKey, activeValue) {
    buttons.forEach((button) => {
      const isActive = button.dataset[dataKey] === activeValue
      button.classList.toggle("is-active", isActive)
      button.setAttribute("aria-pressed", isActive)
    })
  }
}
