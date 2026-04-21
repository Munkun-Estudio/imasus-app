import { Controller } from "@hotwired/stimulus"

// Peek-and-dismiss preview sidebar for material cards.
//
// Populated by a Turbo Frame swap into the layout-level
// `<turbo-frame id="preview">` slot. Dismissal (Escape, backdrop click,
// the X button) clears the frame's innerHTML — Turbo repopulates it on
// the next preview-link click. Focus is restored to whatever was focused
// before the preview opened (usually the card's eye-icon button).
export default class extends Controller {
  static targets = ["dialog"]

  connect() {
    this.previousFocus = document.activeElement
    if (this.hasDialogTarget) this.dialogTarget.focus()
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.innerHTML = ""
      // Clear the frame's src so re-clicking the same eye icon refetches
      // instead of being deduped as a same-URL navigation.
      frame.removeAttribute("src")
    }
    if (this.previousFocus &&
        this.previousFocus !== document.body &&
        typeof this.previousFocus.focus === "function") {
      this.previousFocus.focus()
    }
  }

  // Close when clicking the backdrop (not when clicking inside the dialog).
  backdrop(event) {
    if (event.target === this.element) this.close()
  }
}
