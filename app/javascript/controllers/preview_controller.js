import { Controller } from "@hotwired/stimulus"
import { sessionPageCountProperties, songbookSizeProperties, trackEvent } from "lib/analytics"
import { SettingsStore } from "lib/settings_store"

const SIZE_KEY = "printlyrics-size"
const COLUMNS_KEY = "printlyrics-columns"
const SIZES = ["s", "m", "l", "xl"]

export default class extends Controller {
  static targets = ["pageFrame", "pages", "pageSummary", "layoutStatus", "songFormatTitle", "songFormatGroup"]

  connect() {
    this.settings = new SettingsStore()
    const storedSize = this.settings.get(SIZE_KEY, "m")
    this.defaults = {
      size: SIZES.includes(storedSize) ? storedSize : "m",
      columns: this.settings.get(COLUMNS_KEY, "1") === "2" ? "2" : "1"
    }
    this.saveQueue = Promise.resolve()
    this.activeSongToken = null
    this.scrollFrame = null

    this.songs = this.songSources()
    // Read before the first render replaces the sources with the pages it
    // builds, the way the songs above it are. The mark is one element however
    // many songs the surface holds, because it is cloned onto every page rather
    // than repeated in the markup.
    this.mark = this.element.querySelector("template[data-preview-mark]")?.content.firstElementChild.cloneNode(true)

    this.onScroll = this.onScroll.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })
    window.addEventListener("resize", this.onScroll, { passive: true })

    this.refreshAllControls()
    this.renderPages()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    if (this.scrollFrame) window.cancelAnimationFrame(this.scrollFrame)
  }

  // The markup carries one source per song. A songbook source also carries the
  // layout the server saved for that entry; a single sheet has no saved layout
  // and follows the visitor's stored preference. Sources are read once, because
  // the first render replaces them with the pages it builds.
  songSources() {
    return [...this.pagesTarget.querySelectorAll("[data-preview-song]")].map((source) => ({
      token: source.dataset.previewSongToken,
      layoutUrl: source.dataset.previewLayoutUrl,
      size: source.dataset.previewSize || this.defaults.size,
      columns: String(source.dataset.previewColumns || this.defaults.columns),
      title: source.querySelector(".lyric-header h1")?.textContent.trim(),
      header: source.querySelector(".lyric-header")?.cloneNode(true),
      stanzas: [...source.querySelectorAll(".stanza")].map((node) => node.textContent)
    }))
  }

  setSize(event) {
    this.applyLayout(event, "size")
  }

  setColumns(event) {
    this.applyLayout(event, "columns")
  }

  // A control belongs to one of three scopes: the song the visitor is reading,
  // every song in the set, or the single sheet this page holds. The scoped
  // change repaginates immediately; a songbook change is also saved so a later
  // visit or device prints the same book.
  applyLayout(event, kind) {
    const control = event.currentTarget.closest("[data-preview-layout]")
    if (!control || control.dataset.previewLayout !== kind) return

    const value = event.currentTarget.dataset.previewValue
    const scope = control.dataset.previewLayoutScope

    if (scope === "active") {
      const activeSong = this.songFor(this.activeSongToken)
      if (!activeSong) return

      activeSong[kind] = value
      this.refreshAllControls()
      this.renderPages()
      this.saveSongLayout(activeSong)
    } else if (scope === "all") {
      this.songs.forEach((entry) => { entry[kind] = value })
      this.refreshAllControls()
      this.renderPages()
      this.saveAllLayouts(kind, value)
    } else {
      this.defaults[kind] = value
      this.settings.set(kind === "size" ? SIZE_KEY : COLUMNS_KEY, value)
      this.songs.forEach((entry) => { entry[kind] = value })
      this.refreshAllControls()
      this.renderPages()
    }
  }

  print() {
    const songbookSize = Number(this.element.dataset.songbookSize || 0)
    const isSet = songbookSize > 0

    trackEvent("Print Dialog Opened", {
      entry_method: isSet ? "songbook" : "print_page",
      ...(isSet ? songbookSizeProperties(songbookSize) : {}),
      ...sessionPageCountProperties()
    })

    // Printing a set is its own event as well as part of every print, so the
    // total stays continuous while the set prints stay countable. The size and
    // `entry_method` ride as properties on the dialog event for the same split.
    if (isSet) trackEvent("Songbook Printed", songbookSizeProperties(songbookSize))

    window.print()
  }

  songFor(token) {
    if (!token) return null

    return this.songs.find((song) => song.token === token)
  }

  saveSongLayout(song) {
    this.queueLayoutSave(song.layoutUrl, { size: song.size, columns: song.columns })
  }

  // A bulk control changes one dimension. Sending the other dimension too
  // would flatten a set that deliberately mixes it (all one size, some two
  // columns), so only the chosen dimension travels.
  saveAllLayouts(kind, value) {
    this.queueLayoutSave(this.element.dataset.songbookLayoutUrl, { [kind]: value })
  }

  // Saves run in the order the visitor made them, so a quick sequence of
  // changes cannot land out of order. A failed save leaves the preview alone
  // and says so rather than claiming a format it could not keep.
  queueLayoutSave(url, layout) {
    if (!url || !layout) return

    this.saveQueue = this.saveQueue
      .then(() => this.persistLayout(url, layout))
      .then(() => this.reportLayoutStatus(""))
      .catch(() => this.reportLayoutStatus(this.element.dataset.layoutError || ""))
  }

  async persistLayout(url, layout) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const response = await fetch(url, {
      method: "PATCH",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        ...(token && { "X-CSRF-Token": token })
      },
      body: JSON.stringify(layout)
    })

    if (!response.ok) throw new Error(`Layout update failed (${response.status})`)
  }

  reportLayoutStatus(message) {
    if (this.hasLayoutStatusTarget) this.layoutStatusTarget.textContent = message
  }

  renderPages() {
    this.pagesTarget.replaceChildren()

    this.songs.forEach((song) => this.renderSong(song))

    const count = this.pagesTarget.querySelectorAll(".paper").length
    this.pageSummaryTarget.textContent = count === 1 ?
      this.pageSummaryTarget.dataset.onePageLabel :
      this.pageSummaryTarget.dataset.manyPagesLabel.replace("%{count}", count)
    this.fitPagePreview()
    this.updateActiveSong()
  }

  // Every song opens a sheet in its own saved size and column count, so a set
  // never runs two titles together or imposes one format on every song. Only a
  // song that outgrows one sheet continues onto a bare page, in that same
  // format.
  renderSong(song) {
    let page = this.appendPage(song, song.header)
    if (song.token) page.id = `song-${song.token}`
    let column = page.querySelector(".lyric-column")

    song.stanzas.forEach((text) => {
      const stanza = this.stanzaElement(text)
      column.append(stanza)
      if (this.overflows(column)) {
        stanza.remove()
        column = this.nextColumn(page)
        if (!column) {
          page = this.appendPage(song)
          column = page.querySelector(".lyric-column")
        }
        column.append(stanza)

        if (this.overflows(column)) this.splitOversizedStanza(stanza, () => {
          column = this.nextColumn(page)
          if (!column) {
            page = this.appendPage(song)
            column = page.querySelector(".lyric-column")
          }
          return column
        })
      }
    })
  }

  appendPage(song, header) {
    const paper = document.createElement("article")
    paper.className = `paper size-${song.size}`
    paper.dataset.previewPage = ""
    if (song.token) paper.dataset.previewSongToken = song.token
    if (header) paper.append(header.cloneNode(true))

    const lyrics = document.createElement("div")
    lyrics.className = `lyrics cols-${song.columns}`
    for (let index = 0; index < Number(song.columns); index++) {
      const column = document.createElement("div")
      column.className = "lyric-column"
      lyrics.append(column)
    }
    paper.append(lyrics)
    // A printed set carries the code on each of its sheets, including the bare
    // one a long song continues onto: a loose page still says where it came
    // from.
    if (this.mark) paper.append(this.mark.cloneNode(true))
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

  onScroll() {
    if (this.scrollFrame) return

    this.scrollFrame = window.requestAnimationFrame(() => {
      this.scrollFrame = null
      this.updateActiveSong()
    })
  }

  // The dock follows the sheet under the fixed control bar rather than the
  // scroll position of the track list above it. When the visitor is above the
  // paper, the first song is the one they are about to read.
  updateActiveSong() {
    if (!this.hasSongFormatTitleTarget) return

    const papers = [...this.pagesTarget.querySelectorAll(".paper[data-preview-song-token]")]
    if (papers.length === 0) return

    const line = this.viewportReferenceLine()
    let current = papers[0]
    for (const paper of papers) {
      if (paper.getBoundingClientRect().top <= line) current = paper
      else break
    }

    const token = current.dataset.previewSongToken
    if (token === this.activeSongToken) return

    this.activeSongToken = token
    const song = this.songFor(token)
    if (!song) return

    this.songFormatTitleTarget.textContent = song.title
    if (this.hasSongFormatGroupTarget) {
      const template = this.songFormatGroupTarget.dataset.previewLabelTemplate
      if (template) {
        this.songFormatGroupTarget.setAttribute("aria-label", template.replace("%{title}", song.title))
      }
    }
    this.refreshActiveControls()
    this.refreshBinder()
  }

  // The binder is an index, so the card for the song in view says so without
  // colour alone. The hidden status text carries the same message for a reader
  // who cannot see the accent edge.
  refreshBinder() {
    this.element.querySelectorAll("[data-preview-binder-song]").forEach((card) => {
      const isCurrent = card.dataset.previewBinderSong === this.activeSongToken
      card.classList.toggle("is-current", isCurrent)

      const link = card.querySelector(".songbook-track-link")
      if (link) {
        if (isCurrent) link.setAttribute("aria-current", "location")
        else link.removeAttribute("aria-current")
      }

      const status = card.querySelector("[data-preview-binder-status]")
      if (status) status.hidden = !isCurrent
    })
  }

  // The song occupying the middle of the viewport is the one being read. A line
  // just under the fixed bar would keep the previous song active while its last
  // lines sat at the top of the screen after the next song had filled it.
  viewportReferenceLine() {
    return window.innerHeight / 2
  }

  // Controls show the value in force. On a set, a bulk control is active only
  // when every song agrees; a mixed set leaves both options unselected, and
  // choosing one applies it to the whole book. The dock shows the song the
  // visitor is currently reading.
  refreshAllControls() {
    this.refreshBulkControls()
    this.refreshActiveControls()
  }

  refreshBulkControls() {
    this.element
      .querySelectorAll("[data-preview-layout]")
      .forEach((control) => {
        if (control.dataset.previewLayoutScope === "active") return

        const values = this.songs.map((song) => String(song[control.dataset.previewLayout]))
        const allAgree = values.length > 0 && values.every((value) => value === values[0])
        this.refreshControl(control, allAgree ? values[0] : null)
      })
  }

  refreshActiveControls() {
    const song = this.songFor(this.activeSongToken)
    this.element
      .querySelectorAll("[data-preview-layout-scope='active']")
      .forEach((control) => {
        this.refreshControl(control, song ? song[control.dataset.previewLayout] : null)
      })
  }

  refreshControl(control, activeValue) {
    control.querySelectorAll("button[data-preview-value]").forEach((button) => {
      const isActive = button.dataset.previewValue === String(activeValue)
      button.classList.toggle("is-active", isActive)
      button.setAttribute("aria-pressed", isActive)
    })
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
}
