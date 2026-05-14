import { Controller } from "@hotwired/stimulus"

// Deferred swap behaviour for the material detail gallery: clicking a
// thumbnail fetches the requested full-size media into the main viewer.
// Video sources stay out of the initial DOM and are requested only after
// a thumbnail/play interaction.
//
// Markup contract:
//   - viewer has data-material-gallery-target="viewer"
//   - thumbs emit click → material-gallery#select and carry data-media-url
//     plus data-gallery-active ("true"/"false") for the initial state
//
// No inputs → no work; degrades gracefully when JS is off (first media
// item in DOM is pre-rendered as visible, thumbnails still link to
// blob URLs via <a> if extended later).
export default class extends Controller {
  static targets = ["viewer", "thumb"]

  async select(event) {
    const thumb = event.currentTarget
    const key = thumb.dataset.mediaKey
    if (!key) return

    await this.loadMedia(thumb.dataset.mediaUrl)

    this.thumbTargets.forEach((t) => {
      t.dataset.galleryActive = (t === thumb).toString()
    })
  }

  async playVideo(event) {
    const trigger = event.currentTarget
    await this.loadMedia(trigger.dataset.mediaUrl)
  }

  async loadMedia(url) {
    if (!url || !this.hasViewerTarget) return

    this.pauseActiveVideo()
    const response = await fetch(url, {
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    if (!response.ok) return

    this.viewerTarget.innerHTML = await response.text()
  }

  pauseActiveVideo() {
    if (!this.hasViewerTarget) return

    this.viewerTarget.querySelectorAll("video").forEach((video) => {
      if (!video.paused) video.pause()
    })
  }
}
