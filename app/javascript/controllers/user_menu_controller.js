import { Controller } from "@hotwired/stimulus"

// Bottom-of-sidebar user menu.
//
// Trigger button toggles an upward-opening flyout. Dismissal sources:
//  - Trigger click toggles closed.
//  - Click outside the controller element closes.
//  - Escape key closes (with focus restored to the trigger).
export default class extends Controller {
  static targets = ["trigger", "flyout"]

  connect() {
    this.outsideClick = this.outsideClick.bind(this)
    this.escapeKey   = this.escapeKey.bind(this)
  }

  disconnect() {
    this.removeListeners()
  }

  toggle(event) {
    event.preventDefault()
    if (this.flyoutTarget.hasAttribute("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.flyoutTarget.removeAttribute("hidden")
    this.triggerTarget.setAttribute("aria-expanded", "true")
    document.addEventListener("click", this.outsideClick, true)
    document.addEventListener("keydown", this.escapeKey)
  }

  close() {
    this.flyoutTarget.setAttribute("hidden", "")
    this.triggerTarget.setAttribute("aria-expanded", "false")
    this.removeListeners()
  }

  removeListeners() {
    document.removeEventListener("click", this.outsideClick, true)
    document.removeEventListener("keydown", this.escapeKey)
  }

  outsideClick(event) {
    if (this.element.contains(event.target)) return
    this.close()
  }

  escapeKey(event) {
    if (event.key !== "Escape") return
    this.close()
    this.triggerTarget.focus()
  }
}
