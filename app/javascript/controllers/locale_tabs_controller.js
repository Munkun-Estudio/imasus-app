import { Controller } from "@hotwired/stimulus"

// Presentational tab switcher for multi-locale form panels.
//
// All panels stay in the DOM — switching tabs only toggles visibility, so
// unsaved input in inactive tabs is preserved. Tabs are keyboard-navigable
// (ArrowLeft / ArrowRight / Home / End) per the WAI-ARIA authoring practices
// for tabs.
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    event.preventDefault()
    this.activate(event.currentTarget.dataset.locale, { focus: false })
  }

  key(event) {
    const keys = ["ArrowRight", "ArrowLeft", "Home", "End"]
    if (!keys.includes(event.key)) return

    event.preventDefault()
    const locales = this.tabTargets.map(t => t.dataset.locale)
    const currentIndex = locales.indexOf(this.activeLocale)
    let nextIndex = currentIndex

    if (event.key === "ArrowRight") nextIndex = (currentIndex + 1) % locales.length
    else if (event.key === "ArrowLeft") nextIndex = (currentIndex - 1 + locales.length) % locales.length
    else if (event.key === "Home") nextIndex = 0
    else if (event.key === "End") nextIndex = locales.length - 1

    this.activate(locales[nextIndex], { focus: true })
  }

  activate(locale, { focus }) {
    this.tabTargets.forEach(tab => {
      const active = tab.dataset.locale === locale
      tab.setAttribute("aria-selected", active ? "true" : "false")
      tab.setAttribute("tabindex", active ? "0" : "-1")
      tab.classList.toggle("border-imasus-dark-green", active)
      tab.classList.toggle("text-imasus-dark-green", active)
      tab.classList.toggle("border-transparent", !active)
      tab.classList.toggle("text-imasus-dark-green/50", !active)
      if (active && focus) tab.focus()
    })
    this.panelTargets.forEach(panel => {
      panel.hidden = panel.dataset.locale !== locale
    })
    this.activeLocale = locale
  }

  get activeLocale() {
    const selected = this.tabTargets.find(t => t.getAttribute("aria-selected") === "true")
    return selected?.dataset.locale
  }

  set activeLocale(_value) { /* derived from DOM, no-op setter */ }
}
