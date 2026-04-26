import { Controller } from "@hotwired/stimulus"

// Drag-and-drop file picker around a hidden <input type="file">.
//
// Targets:
//   input  — the hidden file input the label drives.
//   status — paragraph that shows the selected file count.
//
// Values:
//   multiple — boolean; mirrors the input's multiple attribute.
//
// The status paragraph carries three localised templates as data
// attributes (data-empty / data-one / data-other) populated by the
// view, so this controller stays locale-agnostic.
export default class extends Controller {
  static targets = ["input", "status"]
  static values  = { multiple: Boolean }

  connect() {
    this.dragEnter = this.dragEnter.bind(this)
    this.dragLeave = this.dragLeave.bind(this)
    this.dragOver  = this.dragOver.bind(this)
    this.drop      = this.drop.bind(this)

    this.element.addEventListener("dragenter", this.dragEnter)
    this.element.addEventListener("dragleave", this.dragLeave)
    this.element.addEventListener("dragover",  this.dragOver)
    this.element.addEventListener("drop",      this.drop)
  }

  disconnect() {
    this.element.removeEventListener("dragenter", this.dragEnter)
    this.element.removeEventListener("dragleave", this.dragLeave)
    this.element.removeEventListener("dragover",  this.dragOver)
    this.element.removeEventListener("drop",      this.drop)
  }

  dragEnter(event) {
    event.preventDefault()
    this.element.dataset.active = "true"
  }

  dragOver(event) {
    event.preventDefault()
  }

  dragLeave(event) {
    if (event.relatedTarget && this.element.contains(event.relatedTarget)) return
    delete this.element.dataset.active
  }

  drop(event) {
    event.preventDefault()
    delete this.element.dataset.active
    if (!event.dataTransfer || event.dataTransfer.files.length === 0) return
    if (!this.hasInputTarget) return

    const files = this.multipleValue
      ? event.dataTransfer.files
      : new DataTransfer().items.add(event.dataTransfer.files[0]) && (() => {
          const dt = new DataTransfer()
          dt.items.add(event.dataTransfer.files[0])
          return dt.files
        })()

    this.inputTarget.files = files
    this.filesChanged()
  }

  filesChanged() {
    if (!this.hasStatusTarget || !this.hasInputTarget) return
    const count = this.inputTarget.files?.length ?? 0
    const status = this.statusTarget
    if (count === 0) {
      status.textContent = ""
      status.classList.add("hidden")
      return
    }
    const template = count === 1 ? status.dataset.one : status.dataset.other
    status.textContent = template.replace("%{count}", count)
    status.classList.remove("hidden")
  }
}
