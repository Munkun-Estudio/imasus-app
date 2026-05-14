import { Controller } from "@hotwired/stimulus"

// Switches a lazy turbo-frame sentinel to display:contents after it loads so
// its children become direct participants in the surrounding layout (grid or
// space-y list). The sentinel needs a layout box while empty so the browser's
// IntersectionObserver can detect it entering the viewport; once content
// arrives that box is no longer needed and would break the layout.
export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:frame-load", this.#expand)
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.#expand)
  }

  #expand = () => {
    this.element.className = "contents"
    this.element.removeEventListener("turbo:frame-load", this.#expand)
  }
}
