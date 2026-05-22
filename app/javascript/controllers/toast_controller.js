import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 4000 } }

  #timer = null

  connect() {
    // Animate in on the next frame (element must be in DOM first)
    requestAnimationFrame(() => {
      this.element.style.opacity = "1"
      this.element.style.transform = "translateY(0)"
    })

    this.#timer = setTimeout(() => this.dismiss(), this.durationValue)
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  dismiss() {
    clearTimeout(this.#timer)
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-8px)"

    this.element.addEventListener(
      "transitionend",
      () => {
        const container = document.getElementById("flash-toast")
        if (container) container.innerHTML = ""
      },
      { once: true }
    )
  }
}
