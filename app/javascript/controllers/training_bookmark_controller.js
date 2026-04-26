import { Controller } from "@hotwired/stimulus"

// Annotates training module content with per-heading and per-paragraph
// bookmark toggles. Runs client-side so the bookmark icons appear without
// modifying the sanitised HTML on the server.
//
// Expected data attributes on the <article> element:
//   data-controller="training-bookmark"
//   data-training-bookmark-module-slug-value   — e.g. "design-for-longevity"
//   data-training-bookmark-section-value       — e.g. "training-module"
//   data-training-bookmark-locale-value        — e.g. "en"
//   data-training-bookmark-saved-value         — JSON: { "slug/section/locale/anchor": bookmarkId, … }
//   data-training-bookmark-create-url-value    — "/bookmarks"
export default class extends Controller {
  static values = {
    moduleSlug: String,
    section:    String,
    locale:     String,
    saved:      Object,
    createUrl:  String,
  }

  connect() {
    this.annotate()
  }

  annotate() {
    this.element.querySelectorAll("h1, h2, h3, h4, p").forEach(el => {
      if (!el.id) return  // paragraphs already have server-assigned ids; skip if somehow absent

      const resourceKey = `${this.moduleSlugValue}/${this.sectionValue}/${this.localeValue}/${el.id}`
      const bookmarkId  = this.savedValue[resourceKey] ?? null
      const label       = this.labelFor(el)
      const url         = `${window.location.pathname}?locale=${this.localeValue}#${el.id}`

      this.wrapElement(el, resourceKey, bookmarkId, label, url)
    })
  }

  labelFor(el) {
    const text = el.textContent.trim()
    return text.length > 100 ? text.slice(0, 97) + "…" : text
  }

  wrapElement(el, resourceKey, bookmarkId, label, url) {
    const toggleId = `bookmark-toggle-training-${el.id}`

    // Avoid double-wrapping on reconnect
    if (el.parentElement?.classList.contains("bookmark-anchor-wrapper")) return

    const wrapper = document.createElement("div")
    wrapper.className = "bookmark-anchor-wrapper group/anchor relative"

    el.parentNode.insertBefore(wrapper, el)
    wrapper.appendChild(el)

    const btn = this.buildButton(toggleId, resourceKey, bookmarkId, label, url)
    wrapper.appendChild(btn)
  }

  buildButton(toggleId, resourceKey, bookmarkId, label, url) {
    const saved = bookmarkId !== null
    const btn   = document.createElement("button")

    btn.id        = toggleId
    btn.type      = "button"
    btn.title     = saved ? this.t("unsave") : this.t("save")
    btn.className = [
      "bookmark-anchor-btn",
      "absolute -right-8 top-0 z-10",
      saved ? "" : "opacity-0 group-hover/anchor:opacity-100 focus:opacity-100",
      "rounded-full p-1 transition",
      saved
        ? "text-imasus-dark-green"
        : "text-imasus-dark-green/30 hover:text-imasus-dark-green",
    ].join(" ").trim()

    btn.dataset.resourceKey  = resourceKey
    btn.dataset.bookmarkId   = bookmarkId ?? ""
    btn.dataset.label        = label
    btn.dataset.url          = url
    btn.dataset.action       = "click->training-bookmark#toggle"
    btn.innerHTML = saved ? this.filledIcon() : this.outlineIcon()

    return btn
  }

  async toggle(event) {
    const btn        = event.currentTarget
    const resourceKey = btn.dataset.resourceKey
    const bookmarkId  = btn.dataset.bookmarkId || null
    const csrf        = document.querySelector('meta[name="csrf-token"]')?.content

    if (bookmarkId) {
      // Destroy
      const response = await fetch(`/bookmarks/${bookmarkId}`, {
        method:  "DELETE",
        headers: { "X-CSRF-Token": csrf, Accept: "application/json" },
      })
      if (response.ok) {
        btn.dataset.bookmarkId = ""
        btn.title     = this.t("save")
        btn.className = btn.className
          .replace("text-imasus-dark-green", "opacity-0 group-hover/anchor:opacity-100 focus:opacity-100 text-imasus-dark-green/30 hover:text-imasus-dark-green")
          .trim()
        btn.innerHTML = this.outlineIcon()
      }
    } else {
      // Create
      const response = await fetch(this.createUrlValue, {
        method:  "POST",
        headers: {
          "X-CSRF-Token":  csrf,
          "Content-Type":  "application/json",
          Accept:          "application/json",
        },
        body: JSON.stringify({
          bookmark: {
            bookmarkable_type: "TrainingModule",
            resource_key:      resourceKey,
            label:             btn.dataset.label,
            url:               btn.dataset.url,
          },
        }),
      })
      if (response.ok) {
        const data = await response.json()
        btn.dataset.bookmarkId = data.id
        btn.title     = this.t("unsave")
        btn.className = btn.className
          .replace("opacity-0 group-hover/anchor:opacity-100 focus:opacity-100", "")
          .replace("text-imasus-dark-green/30 hover:text-imasus-dark-green", "text-imasus-dark-green")
          .trim()
        btn.innerHTML = this.filledIcon()
      }
    }
  }

  t(key) {
    const translations = {
      save:   document.documentElement.lang === "es" ? "Guardar" :
              document.documentElement.lang === "it" ? "Salva" :
              document.documentElement.lang === "el" ? "Αποθήκευση" : "Save",
      unsave: document.documentElement.lang === "es" ? "Quitar marcador" :
              document.documentElement.lang === "it" ? "Rimuovi segnalibro" :
              document.documentElement.lang === "el" ? "Αφαίρεση σελιδοδείκτη" : "Remove bookmark",
    }
    return translations[key] ?? key
  }

  filledIcon() {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="h-4 w-4">
      <path fill-rule="evenodd" d="M6.32 2.577a49.255 49.255 0 0 1 11.36 0c1.497.174 2.57 1.46 2.57 2.93V21a.75.75 0 0 1-1.085.67L12 18.089l-7.165 3.583A.75.75 0 0 1 3.75 21V5.507c0-1.47 1.073-2.756 2.57-2.93Z" clip-rule="evenodd"/>
    </svg>`
  }

  outlineIcon() {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="h-4 w-4">
      <path stroke-linecap="round" stroke-linejoin="round" d="M17.593 3.322c1.1.128 1.907 1.077 1.907 2.185V21L12 17.25 4.5 21V5.507c0-1.108.806-2.057 1.907-2.185a48.507 48.507 0 0 1 11.186 0Z"/>
    </svg>`
  }
}
