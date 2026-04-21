import { Controller } from "@hotwired/stimulus"

// Plays a material card's <video> only while the card is on screen, pauses it
// otherwise, and refuses to autoplay when the user has asked the OS for
// reduced motion. Degrades silently when the card has no video element.
export default class extends Controller {
  connect() {
    this.video = this.element.querySelector("video")
    if (!this.video) return

    this.prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.prefersReducedMotion) return

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          this.video.play().catch(() => {
            // Autoplay can be blocked by browser policy; fail silently.
          })
        } else {
          this.video.pause()
        }
      })
    }, { threshold: 0.25 })

    this.observer.observe(this.element)
  }

  disconnect() {
    if (this.observer) this.observer.disconnect()
    if (this.video) this.video.pause()
  }
}
