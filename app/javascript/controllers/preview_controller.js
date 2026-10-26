import { Controller } from "@hotwired/stimulus"
import { sessionPageCountProperties, songbookSizeProperties, trackEvent } from "lib/analytics"
import { SettingsStore } from "lib/settings_store"

const SIZE_KEY = "printlyrics-size"
const COLUMNS_KEY = "printlyrics-columns"
const SIZES = ["s", "m", "l", "xl"]

export default class extends Controller {
  static targets = ["pageFrame", "pages", "pageSummary", "layoutStatus", "saveFeedback", "retry", "songFormatTitle", "songFormatGroup", "revisionLink", "zoom"]

  connect() {
    this.settings = new SettingsStore()
    const storedSize = this.settings.get(SIZE_KEY, "m")
    this.defaults = {
      size: SIZES.includes(storedSize) ? storedSize : "m",
      columns: this.settings.get(COLUMNS_KEY, "1") === "2" ? "2" : "1"
    }
    this.saveQueue = Promise.resolve()
    this.pendingLayouts = new Map()
    this.layoutVersion = 0
    this.activeSongToken = null
    this.scrollFrame = null
    this.renderFrame = null
    this.zoom = "fit"

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
    this.requestRenderPages()
    this.resizeObserver = new ResizeObserver(() => this.fitPagePreview())
    this.resizeObserver.observe(this.pageFrameTarget.parentElement)
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
    window.removeEventListener("resize", this.onScroll)
    if (this.scrollFrame) window.cancelAnimationFrame(this.scrollFrame)
    if (this.renderFrame) window.cancelAnimationFrame(this.renderFrame)
    this.resizeObserver?.disconnect()
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

    const affected = scope === "active" ? [this.songFor(this.activeSongToken)].filter(Boolean) : this.songs
    affected.forEach((song) => { song[kind] = value })
    if (scope) {
      affected.forEach((song) => this.markLayoutPending(song, kind, value))
      this.queueLayoutSave()
    } else {
      this.defaults[kind] = value
      this.settings.set(kind === "size" ? SIZE_KEY : COLUMNS_KEY, value)
    }
    this.refreshAllControls()
    this.refreshRevisionLink()
    this.requestRenderPages()
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

  // Track unsaved dimensions, not just the last request. A later successful
  // columns change must never conceal an earlier failed size change.
  markLayoutPending(song, kind, value) {
    const pending = this.pendingLayouts.get(song.token) || {}
    pending[kind] = { value, version: ++this.layoutVersion }
    this.pendingLayouts.set(song.token, pending)
  }

  retryLayouts() {
    this.queueLayoutSave()
  }

  queueLayoutSave() {
    this.saveQueue = this.saveQueue.then(async () => {
      if (this.hasRetryTarget) this.retryTarget.disabled = true
      const snapshots = [...this.pendingLayouts].map(([token, dimensions]) => [token, { ...dimensions }])
      for (const [token, dimensions] of snapshots) {
        const song = this.songFor(token)
        if (!song) continue

        const layout = Object.fromEntries(Object.entries(dimensions).map(([kind, change]) => [kind, change.value]))
        try {
          await this.persistLayout(song.layoutUrl, layout)
          const pending = this.pendingLayouts.get(token)
          for (const [kind, change] of Object.entries(dimensions)) {
            if (pending?.[kind]?.version === change.version) delete pending[kind]
          }
          if (pending && Object.keys(pending).length === 0) this.pendingLayouts.delete(token)
        } catch {
          // Keep every failed dimension for the next change or explicit retry.
        }
      }
      this.reportLayoutStatus(this.pendingLayouts.size > 0 ? this.element.dataset.layoutError : "")
      if (this.hasRetryTarget) this.retryTarget.disabled = false
    })
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
    if (this.hasLayoutStatusTarget) this.layoutStatusTarget.textContent = message || ""
    if (this.hasSaveFeedbackTarget) this.saveFeedbackTarget.hidden = !message
  }

  requestRenderPages() {
    this.pagesTarget.setAttribute("aria-busy", "true")
    this.pageSummaryTarget.textContent = this.pageSummaryTarget.dataset.measuringLabel
    if (this.renderFrame) window.cancelAnimationFrame(this.renderFrame)
    this.renderFrame = window.requestAnimationFrame(() => {
      this.renderFrame = null
      this.renderPages()
    })
  }

  renderPages() {
    const anchor = this.activeSongToken && document.getElementById(`song-${this.activeSongToken}`)
    const anchorTop = anchor?.getBoundingClientRect().top
    this.pagesTarget.replaceChildren()
    this.songs.forEach((song) => this.renderSong(song))

    const count = this.pagesTarget.querySelectorAll(".paper").length
    this.pageSummaryTarget.textContent = count === 1 ?
      this.pageSummaryTarget.dataset.onePageLabel :
      this.pageSummaryTarget.dataset.manyPagesLabel.replace("%{count}", count)
    this.pagesTarget.setAttribute("aria-busy", "false")
    this.fitPagePreview()
    if (anchorTop !== undefined) {
      const replacement = document.getElementById(`song-${this.activeSongToken}`)
      if (replacement) window.scrollBy(0, replacement.getBoundingClientRect().top - anchorTop)
    }
    this.updateActiveSong()
    this.refreshRevisionLink()
    this.refreshBinder()
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

  selectSong(event) {
    const token = event.currentTarget.closest("[data-preview-binder-song]")?.dataset.previewBinderSong
    const paper = token && document.getElementById(`song-${token}`)
    if (!paper) return

    event.preventDefault()
    // Close a compact outline before measuring the page's scroll destination.
    const outline = event.currentTarget.closest("details")
    if (outline && !window.matchMedia("(min-width: 1440px)").matches) outline.open = false
    paper.scrollIntoView({ block: "start", behavior: "instant" })
    this.setActiveSong(token)
  }

  // Reading position follows the paper, never the outline's own scroll.
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

    this.setActiveSong(current.dataset.previewSongToken)
  }

  setActiveSong(token) {
    if (token === this.activeSongToken) return
    const song = this.songFor(token)
    if (!song) return

    this.activeSongToken = token

    this.songFormatTitleTarget.textContent = song.title
    if (this.hasSongFormatGroupTarget) {
      const template = this.songFormatGroupTarget.dataset.previewLabelTemplate
      if (template) {
        this.songFormatGroupTarget.setAttribute("aria-label", template.replace("%{title}", song.title))
      }
    }
    this.refreshActiveControls()
    this.refreshBinder()
    this.refreshRevisionLink()
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
      const song = this.songFor(card.dataset.previewBinderSong)
      const format = card.querySelector("[data-preview-binder-format]")
      if (song && format) {
        const columns = song.columns === "2" ? format.dataset.twoColumnsLabel : format.dataset.oneColumnLabel
        format.textContent = format.dataset.formatTemplate.replace("%{size}", song.size.toUpperCase()).replace("%{columns}", columns)
      }
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
    const mixed = control.querySelector("[data-preview-mixed]")
    if (mixed) mixed.hidden = activeValue !== null
    control.querySelectorAll("button[data-preview-value]").forEach((button) => {
      const isActive = button.dataset.previewValue === String(activeValue)
      button.classList.toggle("is-active", isActive)
      button.setAttribute("aria-pressed", isActive)
    })
  }

  refreshRevisionLink() {
    if (!this.hasRevisionLinkTarget) return

    const song = this.songFor(this.activeSongToken) || this.songs[0]
    if (!song) return

    const url = new URL(this.revisionLinkTarget.href)
    if (song.token) url.searchParams.set("revision", song.token)
    url.searchParams.set("size", song.size)
    url.searchParams.set("columns", song.columns)
    this.revisionLinkTarget.href = url.toString()
  }

  setZoom(event) {
    this.zoom = event.currentTarget.value
    this.fitPagePreview()
    this.updateActiveSong()
  }

  fitPagePreview() {
    if (window.matchMedia("print").matches) return

    const page = this.pagesTarget.firstElementChild
    if (!page) return

    const stage = this.pageFrameTarget.parentElement
    const style = window.getComputedStyle(stage)
    const available = stage.clientWidth - parseFloat(style.paddingLeft) - parseFloat(style.paddingRight)
    const scale = this.zoom === "fit" ? Math.min(1, available / page.offsetWidth) : Number(this.zoom) / 100
    this.pagesTarget.style.setProperty("--preview-scale", scale)
    this.pageFrameTarget.style.width = `${page.offsetWidth * scale}px`
    this.pageFrameTarget.style.height = `${this.pagesTarget.scrollHeight * scale}px`
  }

  restorePagePreview() {
    window.requestAnimationFrame(() => this.fitPagePreview())
  }
}
