import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["page", "lyrics", "sizeButton", "columnButton", "mobileNote"]

  connect() {
    this.setSizeState(this.readSetting("printlyrics-size", "m"))
    this.setColumnState(this.readSetting("printlyrics-columns", "1"))
  }

  setSize(event) {
    const size = event.currentTarget.dataset.size
    this.setSizeState(size)
    this.writeSetting("printlyrics-size", size)
  }

  setColumns(event) {
    const columns = event.currentTarget.dataset.columns
    this.setColumnState(columns)
    this.writeSetting("printlyrics-columns", columns)
  }

  print() {
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
    this.mobileNoteTarget.hidden = columns !== "2"
  }

  updatePressedState(buttons, dataKey, activeValue) {
    buttons.forEach((button) => {
      const isActive = button.dataset[dataKey] === activeValue
      button.classList.toggle("is-active", isActive)
      button.setAttribute("aria-pressed", isActive)
    })
  }

  readSetting(key, fallback) {
    try {
      return localStorage.getItem(key) || fallback
    } catch {
      return fallback
    }
  }

  writeSetting(key, value) {
    try {
      localStorage.setItem(key, value)
    } catch {
      // Preview controls still work when storage is unavailable.
    }
  }
}
