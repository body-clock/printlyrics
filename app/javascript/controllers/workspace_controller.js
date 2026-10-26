import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["inspector", "trigger", "heading", "outline"]

  connect() {
    this.inspectorOpen = false
    this.inlineInspector = window.matchMedia("(min-width: 1100px)")
    this.wideOutline = window.matchMedia("(min-width: 1440px)")
    this.onLayoutChange = this.updateLayout.bind(this)
    this.inlineInspector.addEventListener("change", this.onLayoutChange)
    this.wideOutline.addEventListener("change", this.onLayoutChange)
    this.updateLayout()
    this.toolbarObserver = new ResizeObserver(([entry]) => {
      this.element.style.setProperty("--workspace-toolbar-height", `${entry.borderBoxSize[0].blockSize}px`)
    })
    this.toolbarObserver.observe(this.element.querySelector(".control-bar"))
  }

  disconnect() {
    this.inlineInspector.removeEventListener("change", this.onLayoutChange)
    this.wideOutline.removeEventListener("change", this.onLayoutChange)
    this.toolbarObserver.disconnect()
  }

  toggleInspector() {
    if (this.inspectorOpen) this.closeInspector()
    else this.openInspector()
  }

  openInspector() {
    this.inspectorOpen = true
    this.updateInspector()
    this.headingTarget.focus({ preventScroll: true })
  }

  closeInspector() {
    if (this.inlineInspector.matches) return

    this.inspectorOpen = false
    this.updateInspector()
    this.triggerTarget.focus({ preventScroll: true })
  }

  escape(event) {
    if (event.key !== "Escape" || !this.inspectorOpen || this.inlineInspector.matches) return

    event.preventDefault()
    this.closeInspector()
  }

  updateLayout() {
    this.updateInspector()
    if (this.hasOutlineTarget) this.outlineTarget.open = this.wideOutline.matches
  }

  updateInspector() {
    const visible = this.inlineInspector.matches || this.inspectorOpen
    this.inspectorTarget.hidden = !visible
    this.inspectorTarget.dataset.open = String(this.inspectorOpen)
    this.inspectorTarget.dataset.inline = String(this.inlineInspector.matches)
    this.triggerTarget.setAttribute("aria-expanded", String(visible))
  }

  navigateOutline() {
    if (this.hasOutlineTarget && !this.wideOutline.matches) this.outlineTarget.open = false
  }
}
