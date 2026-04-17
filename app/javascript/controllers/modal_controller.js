import { Controller } from "@hotwired/stimulus"

// Lightweight modal controller for Turbo Frame modals.
//
// The modal content is rendered inside a top-level `<turbo-frame id="modal">`.
// Dismissal (Escape, backdrop click, Cancel button) works by clearing the
// frame's innerHTML — Turbo will re-populate it on the next modal link click.
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.previousFocus = document.activeElement
    if (this.hasDialogTarget) this.dialogTarget.focus()
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.innerHTML = ""
    if (this.previousFocus && typeof this.previousFocus.focus === "function") {
      this.previousFocus.focus()
    }
  }

  // Close when clicking the backdrop (not when clicking inside the dialog).
  backdrop(event) {
    if (event.target === this.element) this.close()
  }
}
