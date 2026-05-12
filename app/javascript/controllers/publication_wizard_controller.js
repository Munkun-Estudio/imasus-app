import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "dot", "logEntry"]
  static values = {
    problemHeading:  String,
    processHeading:  String,
    insightsHeading: String,
    outcomeHeading:  String,
  }

  connect() {
    this.currentStep = 0
    this.assembled   = false

    if (this.element.querySelector("[data-role='errors']")) {
      this.currentStep = this.stepTargets.length - 1
    }

    this.renderStep()
  }

  next() {
    const next = this.currentStep + 1
    if (next === this.stepTargets.length - 1 && !this.assembled) {
      this.assembleContent()
      this.assembled = true
    }
    this.currentStep = Math.min(next, this.stepTargets.length - 1)
    this.renderStep()
  }

  back() {
    this.currentStep = Math.max(0, this.currentStep - 1)
    this.renderStep()
  }

  renderStep() {
    this.stepTargets.forEach((step, i) => {
      step.hidden = i !== this.currentStep
    })
    this.dotTargets.forEach((dot, i) => {
      dot.setAttribute("aria-current", i === this.currentStep ? "step" : "false")
    })
  }

  assembleContent() {
    const sections = [
      { id: "wizard_problem",  key: "problem",  heading: this.problemHeadingValue },
      { id: "wizard_process",  key: "process",  heading: this.processHeadingValue },
      { id: "wizard_insights", key: "insights", heading: this.insightsHeadingValue },
      { id: "wizard_outcome",  key: "outcome",  heading: this.outcomeHeadingValue },
    ]

    const html = sections
      .map(({ id, key, heading }) => {
        const val = document.getElementById(id)?.value?.trim()
        const logHTML = this.selectedLogEntriesHTML(key)
        return val || logHTML ? `<h1>${this.escapeHTML(heading)}</h1>${val ? this.paragraphHTML(val) : ""}${logHTML}` : null
      })
      .filter(Boolean)
      .join("")

    if (!html) return

    const trix = this.element.querySelector("trix-editor")
    if (trix && trix.editor) trix.editor.loadHTML(html)
  }

  paragraphHTML(text) {
    return text
      .split(/\n{2,}/)
      .map((paragraph) => `<p>${this.escapeHTML(paragraph).replace(/\n/g, "<br>")}</p>`)
      .join("")
  }

  selectedLogEntriesHTML(section) {
    if (!this.hasLogEntryTarget) return ""

    return this.logEntryTargets
      .filter((entry) => entry.checked && entry.dataset.section === section)
      .map((entry) => this.logEntryHTML(entry))
      .join("")
  }

  logEntryHTML(entry) {
    const body = entry.dataset.entryBody?.trim()
    const author = entry.dataset.entryAuthor?.trim()
    const date = entry.dataset.entryDate?.trim()
    const media = this.parseMedia(entry.dataset.entryMedia)

    const bodyHTML = body ? `<blockquote>${this.paragraphHTML(body)}</blockquote>` : ""
    const caption = [author, date].filter(Boolean).map((value) => this.escapeHTML(value)).join(" · ")
    const captionHTML = caption ? `<p><em>${caption}</em></p>` : ""

    return `${bodyHTML}${this.mediaHTML(media)}${captionHTML}`
  }

  // Emit the figure markup Trix recognizes natively. Trix's HTML parser does
  // not understand bare `<action-text-attachment>` elements, so injecting them
  // via `editor.loadHTML` silently strips them on serialization and the saved
  // body ends up text-only. The `data-trix-attachment` attribute is the
  // supported handoff: Trix picks up the JSON, registers the attachment, and
  // round-trips it through ActionText storage.
  mediaHTML(media) {
    return media
      .map((item) => {
        if (!item.sgid) return ""

        const attrs = {
          sgid:        item.sgid,
          contentType: item.content_type,
          filename:    item.filename,
          filesize:    item.filesize,
          width:       item.width,
          height:      item.height,
          url:         item.url,
          previewable: item.previewable,
        }
        const json = this.escapeAttribute(JSON.stringify(attrs))
        const contentType = this.escapeAttribute(item.content_type || "")
        return `<figure data-trix-attachment="${json}" data-trix-content-type="${contentType}"></figure>`
      })
      .join("")
  }

  parseMedia(value) {
    if (!value) return []

    try {
      return JSON.parse(value)
    } catch (_error) {
      return []
    }
  }

  escapeHTML(value) {
    return value.replace(/[&<>"']/g, (char) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;",
      "'": "&#39;",
    }[char]))
  }

  escapeAttribute(value) {
    return this.escapeHTML(value)
  }
}
