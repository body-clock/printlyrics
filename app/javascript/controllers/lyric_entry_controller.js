import { Controller } from "@hotwired/stimulus"
import { sessionStore, SettingsStore } from "lib/settings_store"

const drafts = new Map()
const PENDING_KEY = "printlyrics-entry-pending"
const FIELDS = ["title", "artist", "lyrics"]

// A completed full-page POST clears only the draft that produced it. A failed
// validation renders the entry again and keeps its server-returned values.
function clearCompletedDraft() {
  if (!document.body?.dataset.generatedPageKey) return

  const store = sessionStore()
  const key = store.get(PENDING_KEY, null)
  if (key) {
    store.remove(key)
    drafts.delete(key)
  }
  store.remove(PENDING_KEY)
}

document.addEventListener("turbo:load", clearCompletedDraft)
// Controller imports can finish after the initial Turbo load event.
clearCompletedDraft()

export default class extends Controller {
  static targets = ["tab", "panel", "editor", "catalog", "status"]
  static values = {
    context: String, response: String, mode: String, size: String, columns: String,
    saved: String, recovered: String, unavailable: String, leave: String
  }

  connect() {
    this.store = sessionStore()
    this.key = `printlyrics-entry:${this.contextValue}`
    this.leaving = false
    this.baseline = this.words()
    this.dirty = ["selected", "validation"].includes(this.responseValue)
    const draft = this.readDraft()
    const authoritative = ["selected", "validation"].includes(this.responseValue)
    if (draft && !authoritative) {
      FIELDS.forEach((field) => { this.field(field).value = draft.fields[field] || "" })
      this.catalogTarget.value = draft.catalog || ""
      this.baseline = draft.baseline || this.baseline
      this.dirty = Boolean(draft.dirty)
      if (this.responseValue !== "search") {
        this.modeValue = draft.mode === "paste" ? "paste" : "find"
        this.query.value = draft.query || ""
      }
    }
    this.showMode(this.modeValue || "find")
    this.persist(Boolean(draft && !authoritative))
    if (this.responseValue === "selected" || this.responseValue === "validation") {
      requestAnimationFrame(() => this.field("lyrics").focus())
    }
  }

  get query() {
    return this.element.querySelector('input[name="query"]')
  }

  field(name) {
    return this.editorTarget.elements.namedItem(`lyric[${name}]`)
  }

  words() {
    return Object.fromEntries(FIELDS.map((field) => [field, this.field(field).value]))
  }

  readDraft() {
    try {
      const draft = drafts.get(this.key) || JSON.parse(this.store.get(this.key, "null"))
      return draft && draft.fields && FIELDS.every((field) => typeof draft.fields[field] === "string") ? draft : null
    } catch {
      return null
    }
  }

  changed() {
    this.dirty = JSON.stringify(this.words()) !== JSON.stringify(this.baseline)
    this.persist()
  }

  persist(recovered = false) {
    const draft = {
      fields: this.words(), catalog: this.catalogTarget.value,
      query: this.query.value, mode: this.modeValue, baseline: this.baseline, dirty: this.dirty
    }
    drafts.set(this.key, draft)
    const serialized = JSON.stringify(draft)
    this.store.set(this.key, serialized)
    const saved = this.store.get(this.key, null) === serialized
    this.statusTarget.textContent = saved ? (recovered ? this.recoveredValue : this.savedValue) : this.unavailableValue
    this.statusTarget.hidden = !this.dirty && !recovered
  }

  switchMode(event) {
    this.showMode(event.currentTarget.dataset.mode)
    this.persist()
  }

  showMode(mode) {
    this.modeValue = mode
    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.mode === mode
      tab.setAttribute("aria-selected", String(selected))
      tab.tabIndex = selected ? 0 : -1
    })
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.mode !== mode })
  }

  navigateTabs(event) {
    const current = this.tabTargets.indexOf(event.target)
    if (current < 0) return
    let next
    if (event.key === "ArrowRight") next = (current + 1) % this.tabTargets.length
    if (event.key === "ArrowLeft") next = (current - 1 + this.tabTargets.length) % this.tabTargets.length
    if (event.key === "Home") next = 0
    if (event.key === "End") next = this.tabTargets.length - 1
    if (next === undefined) return
    event.preventDefault()
    this.tabTargets[next].focus()
    this.showMode(this.tabTargets[next].dataset.mode)
    this.persist()
  }

  paste(event) {
    event.preventDefault()
    this.showMode("paste")
    this.field("lyrics").focus()
    this.persist()
  }

  carryDraft(event) {
    if (!event.target.matches('[data-analytics-submit="Song Search Submitted"], [data-analytics-submit="Song Result Selected"]')) return
    FIELDS.forEach((field) => event.formData.set(`lyric[${field}]`, this.field(field).value))
    event.formData.set("catalog_token", this.catalogTarget.value)
  }

  submitting(event) {
    if (event.target === this.editorTarget) {
      this.persist()
      this.store.set(PENDING_KEY, this.key)
      const settings = new SettingsStore()
      if (this.sizeValue) settings.set("printlyrics-size", this.sizeValue)
      if (this.columnsValue) settings.set("printlyrics-columns", this.columnsValue)
      this.leaving = true
    } else if (event.target.dataset.analyticsSubmit === "Song Result Selected" && this.dirty && this.field("lyrics").value.trim()) {
      if (!window.confirm(this.leaveValue)) {
        event.preventDefault()
        event.stopImmediatePropagation()
      }
    }
  }

  cancel(event) {
    if (this.dirty && !window.confirm(this.leaveValue)) {
      event.preventDefault()
      return
    }
    this.store.remove(this.key)
    drafts.delete(this.key)
    this.leaving = true
  }

  beforeVisit(event) {
    if (this.leaving || !this.dirty) return
    this.persist()
    if (!window.confirm(this.leaveValue)) event.preventDefault()
  }

  beforeUnload(event) {
    if (this.leaving || !this.dirty) return
    this.persist()
    event.preventDefault()
    event.returnValue = ""
  }
}
