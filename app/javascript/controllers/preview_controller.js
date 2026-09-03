import { Controller } from "@hotwired/stimulus"
import { trackEvent } from "lib/analytics"
import { SettingsStore } from "lib/settings_store"

const SIZE_KEY = "printlyrics-size"
const COLUMNS_KEY = "printlyrics-columns"

export default class extends Controller {
  static targets = ["pageFrame", "pages", "pageSummary", "sizeButton", "columnButton"]

  connect() {
    this.settings = new SettingsStore()
    this.header = this.pagesTarget.querySelector(".lyric-header")?.cloneNode(true)
    this.stanzas = [...this.pagesTarget.querySelectorAll(".stanza")].map((node) => node.textContent)
    this.size = this.settings.get(SIZE_KEY, "m")
    this.columns = this.settings.get(COLUMNS_KEY, "1")
    this.updatePressedState(this.sizeButtonTargets, "size", this.size)
    this.updatePressedState(this.columnButtonTargets, "columns", this.columns)
    this.renderPages()
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
    trackEvent("Print Dialog Opened", { entry_method: "print_page" })
    window.print()
  }

  setSizeState(size) {
    this.size = size
    this.updatePressedState(this.sizeButtonTargets, "size", size)
    this.renderPages()
  }

  setColumnState(columns) {
    this.columns = columns
    this.updatePressedState(this.columnButtonTargets, "columns", columns)
    this.renderPages()
  }

  renderPages() {
    this.pagesTarget.replaceChildren()
    let page = this.appendPage(this.header)
    let column = page.querySelector(".lyric-column")

    this.stanzas.forEach((text) => {
      const stanza = this.stanzaElement(text)
      column.append(stanza)
      if (this.overflows(column)) {
        stanza.remove()
        column = this.nextColumn(page)
        if (!column) {
          page = this.appendPage()
          column = page.querySelector(".lyric-column")
        }
        column.append(stanza)

        if (this.overflows(column)) this.splitOversizedStanza(stanza, () => {
          column = this.nextColumn(page)
          if (!column) {
            page = this.appendPage()
            column = page.querySelector(".lyric-column")
          }
          return column
        })
      }
    })

    const count = this.pagesTarget.children.length
    this.pageSummaryTarget.textContent = count === 1 ?
      this.pageSummaryTarget.dataset.onePageLabel :
      this.pageSummaryTarget.dataset.manyPagesLabel.replace("%{count}", count)
    this.fitPagePreview()
  }

  appendPage(header) {
    const paper = document.createElement("article")
    paper.className = `paper size-${this.size}`
    paper.dataset.previewPage = ""
    if (header) paper.append(header.cloneNode(true))

    const lyrics = document.createElement("div")
    lyrics.className = `lyrics cols-${this.columns}`
    for (let index = 0; index < Number(this.columns); index++) {
      const column = document.createElement("div")
      column.className = "lyric-column"
      lyrics.append(column)
    }
    paper.append(lyrics)
    this.pagesTarget.append(paper)
    return paper
  }

  nextColumn(page) {
    const columns = [...page.querySelectorAll(".lyric-column")]
    return columns.find((column) => column.childElementCount === 0)
  }

  splitOversizedStanza(stanza, nextColumn) {
    let remaining = stanza.textContent

    while (this.overflows(stanza.parentElement) && remaining.length > 1) {
      let low = 1
      let high = remaining.length

      while (low < high) {
        const midpoint = Math.ceil((low + high) / 2)
        stanza.textContent = remaining.slice(0, midpoint)
        if (this.overflows(stanza.parentElement)) high = midpoint - 1
        else low = midpoint
      }

      let splitAt = Math.max(1, low)
      const naturalBreak = Math.max(
        remaining.lastIndexOf("\n", splitAt),
        remaining.lastIndexOf(" ", splitAt)
      )
      if (naturalBreak >= splitAt / 2) splitAt = naturalBreak + 1

      stanza.textContent = remaining.slice(0, splitAt).trimEnd()
      remaining = remaining.slice(splitAt).trimStart()
      const column = nextColumn()
      stanza = this.stanzaElement(remaining)
      column.append(stanza)
    }
  }

  stanzaElement(text) {
    const stanza = document.createElement("section")
    stanza.className = "stanza"
    stanza.textContent = text
    return stanza
  }

  overflows(column) {
    return column.scrollHeight > column.clientHeight + 1
  }

  fitPagePreview() {
    if (window.matchMedia("print").matches) return

    if (!window.matchMedia("(max-width: 700px)").matches) {
      this.pagesTarget.style.removeProperty("--preview-scale")
      this.pageFrameTarget.style.removeProperty("height")
      return
    }

    const page = this.pagesTarget.firstElementChild
    if (!page) return
    const scale = Math.min(1, this.pageFrameTarget.clientWidth / page.offsetWidth)
    this.pagesTarget.style.setProperty("--preview-scale", scale)
    this.pageFrameTarget.style.height = `${this.pagesTarget.scrollHeight * scale}px`
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
