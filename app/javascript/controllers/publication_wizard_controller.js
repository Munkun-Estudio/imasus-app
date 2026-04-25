import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["step", "dot"]
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
      { id: "wizard_problem",  heading: this.problemHeadingValue },
      { id: "wizard_process",  heading: this.processHeadingValue },
      { id: "wizard_insights", heading: this.insightsHeadingValue },
      { id: "wizard_outcome",  heading: this.outcomeHeadingValue },
    ]

    const html = sections
      .map(({ id, heading }) => {
        const val = document.getElementById(id)?.value?.trim()
        return val ? `<h1>${this.escapeHTML(heading)}</h1>${this.paragraphHTML(val)}` : null
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

  escapeHTML(value) {
    return value.replace(/[&<>"']/g, (char) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      "\"": "&quot;",
      "'": "&#39;",
    }[char]))
  }
}
