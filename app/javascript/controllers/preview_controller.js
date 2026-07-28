import { Controller } from "@hotwired/stimulus"
import { SettingsStore } from "lib/settings_store"

const SIZE_KEY = "printlyrics-size"
const COLUMNS_KEY = "printlyrics-columns"

export default class extends Controller {
  static targets = ["page", "lyrics", "sizeButton", "columnButton", "mobileNote"]

  connect() {
    this.settings = new SettingsStore()
    this.setSizeState(this.settings.get(SIZE_KEY, "m"))
    this.setColumnState(this.settings.get(COLUMNS_KEY, "1"))
  }

  setSize(event) {
    const size = event.currentTarget.dataset.size
    this.setSizeState(size)
    this.settings.set(SIZE_KEY, size)
  }

  setColumns(event) {
    const columns = event.currentTarget.dataset.columns
    this.setColumnState(columns)
    this.settings.set(COLUMNS_KEY, columns)
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
}
