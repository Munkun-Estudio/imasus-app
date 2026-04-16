import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "sidebar", "backdrop"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
  }

  toggle() {
    if (this.isOpen()) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.sidebarTarget.classList.remove("-translate-x-full")
    this.sidebarTarget.classList.add("translate-x-0")
    this.backdropTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.handleKeydown)
  }

  close() {
    this.sidebarTarget.classList.add("-translate-x-full")
    this.sidebarTarget.classList.remove("translate-x-0")
    this.backdropTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.handleKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  isOpen() {
    return this.sidebarTarget.classList.contains("translate-x-0")
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
  }
}
