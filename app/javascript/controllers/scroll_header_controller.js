import { Controller } from "@hotwired/stimulus"

// Hides the header when scrolling down, shows it when scrolling up.
// Always visible near the top of the page.
export default class extends Controller {
  static values = {
    threshold: { type: Number, default: 80 }, // px scrolled before hiding kicks in
    delta:     { type: Number, default: 6 }   // min px delta to consider a real scroll
  }

  connect() {
    this.lastY = window.scrollY
    this.ticking = false
    this.onScroll = this.onScroll.bind(this)

    // Smooth transition class
    this.element.classList.add("transition-transform", "duration-300", "will-change-transform")

    window.addEventListener("scroll", this.onScroll, { passive: true })
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  onScroll() {
    if (this.ticking) return
    this.ticking = true
    window.requestAnimationFrame(() => {
      this.update()
      this.ticking = false
    })
  }

  update() {
    const y = window.scrollY
    const diff = y - this.lastY

    // Ignore tiny scrolls (avoids jitter)
    if (Math.abs(diff) < this.deltaValue) return

    // Always show near the top
    if (y < this.thresholdValue) {
      this.show()
    } else if (diff > 0) {
      this.hide()
    } else {
      this.show()
    }

    this.lastY = y
  }

  hide() {
    this.element.classList.add("-translate-y-full")
  }

  show() {
    this.element.classList.remove("-translate-y-full")
  }
}
