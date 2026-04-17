import { Controller } from "@hotwired/stimulus"

// Click-to-reveal popover for glossary terms wrapped by GlossaryHighlighter.
//
// Design notes:
//
// * Activation is click only — hover would conflict with touch devices and
//   interfere with text selection in longer reading flows.
// * Popover body is fetched on first open from `/glossary/:slug/popover` and
//   cached on the controller instance for subsequent opens.
// * One popover is visible at a time: opening a new one closes any that is
//   already open.
// * Dismissed by Escape, outside click, or clicking the trigger again.
// * Focus returns to the trigger on close for accessibility.
export default class extends Controller {
  static values = { slug: String }

  static _open = null

  connect() {
    this.element.setAttribute("aria-haspopup", "dialog")
    this.element.setAttribute("aria-expanded", "false")
    this.element.addEventListener("click", this.toggle)
    this.element.addEventListener("keydown", this.onKeydown)
  }

  disconnect() {
    this.close()
    this.element.removeEventListener("click", this.toggle)
    this.element.removeEventListener("keydown", this.onKeydown)
  }

  toggle = (event) => {
    event.preventDefault()
    event.stopPropagation()
    if (this.isOpen) this.close()
    else this.open()
  }

  onKeydown = (event) => {
    if (event.key === "Escape" && this.isOpen) {
      event.preventDefault()
      this.close()
    }
  }

  async open() {
    if (this.constructor._open && this.constructor._open !== this) {
      this.constructor._open.close()
    }

    const popover = this.popoverElement ??= await this.buildPopover()
    if (!popover) return

    document.body.appendChild(popover)
    this.position(popover)
    popover.hidden = false

    this.element.setAttribute("aria-expanded", "true")
    this.constructor._open = this

    this.outsideListener = (e) => {
      if (!popover.contains(e.target) && !this.element.contains(e.target)) this.close()
    }
    this.escListener = (e) => { if (e.key === "Escape") this.close() }
    this.repositionListener = () => this.position(popover)

    setTimeout(() => {
      document.addEventListener("click", this.outsideListener)
      document.addEventListener("keydown", this.escListener)
      window.addEventListener("resize", this.repositionListener)
      window.addEventListener("scroll", this.repositionListener, true)
    }, 0)
  }

  close() {
    if (!this.isOpen) return
    this.popoverElement?.remove()
    this.popoverElement = null
    this.element.setAttribute("aria-expanded", "false")
    this.element.focus()
    if (this.constructor._open === this) this.constructor._open = null

    if (this.outsideListener) document.removeEventListener("click", this.outsideListener)
    if (this.escListener) document.removeEventListener("keydown", this.escListener)
    if (this.repositionListener) {
      window.removeEventListener("resize", this.repositionListener)
      window.removeEventListener("scroll", this.repositionListener, true)
    }
  }

  async buildPopover() {
    try {
      const response = await fetch(`/glossary/${this.slugValue}/popover`, {
        headers: { "Accept": "text/html" },
        credentials: "same-origin"
      })
      if (!response.ok) return null

      const html = await response.text()
      const popover = document.createElement("div")
      popover.className = "glossary-popover"
      popover.setAttribute("role", "dialog")
      popover.setAttribute("aria-labelledby", `glossary-popover-${this.slugValue}`)
      popover.hidden = true
      popover.innerHTML = html
      const heading = popover.querySelector(".glossary-popover__term")
      if (heading) heading.id = `glossary-popover-${this.slugValue}`
      return popover
    } catch (_e) {
      return null
    }
  }

  position(popover) {
    const rect = this.element.getBoundingClientRect()
    const top = window.scrollY + rect.bottom + 6
    const left = Math.max(8, window.scrollX + rect.left)
    popover.style.position = "absolute"
    popover.style.top = `${top}px`
    popover.style.left = `${left}px`
    popover.style.zIndex = "60"
  }

  get isOpen() {
    return !!this.popoverElement && !this.popoverElement.hidden
  }
}
