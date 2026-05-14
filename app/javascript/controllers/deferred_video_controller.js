import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  async load() {
    if (!this.hasUrlValue) return

    const response = await fetch(this.urlValue, {
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    if (!response.ok) return

    this.element.innerHTML = await response.text()
  }
}
