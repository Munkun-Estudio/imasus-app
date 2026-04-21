import { Controller } from "@hotwired/stimulus"

// Swap behaviour for the material detail gallery: clicking a thumbnail
// promotes the matching <img> or <video> element inside the main viewer
// and hides the others. Videos are paused when they lose focus so only
// the active one can play.
//
// Markup contract:
//   - viewer has data-material-gallery-target="media" + data-media-key
//   - thumbs emit click → material-gallery#select, carry data-media-key
//     and data-gallery-active ("true"/"false") for the initial state
//
// No inputs → no work; degrades gracefully when JS is off (first media
// item in DOM is pre-rendered as visible, thumbnails still link to
// blob URLs via <a> if extended later).
export default class extends Controller {
  static targets = ["media", "thumb"]

  select(event) {
    const thumb = event.currentTarget
    const key = thumb.dataset.mediaKey
    if (!key) return

    this.mediaTargets.forEach((media) => {
      const active = media.dataset.mediaKey === key
      media.classList.toggle("hidden", !active)
      if (!active && media.tagName === "VIDEO" && !media.paused) {
        media.pause()
      }
    })

    this.thumbTargets.forEach((t) => {
      t.dataset.galleryActive = (t === thumb).toString()
    })
  }
}
