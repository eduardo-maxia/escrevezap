import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "icon", "item"]

  connect() {
    this._handleOutsideClick = this._handleOutsideClick.bind(this)
    this.isOpen = false
  }

  disconnect() {
    document.removeEventListener("click", this._handleOutsideClick)
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true

    // Show menu container (opacity-only transition, no layout shift)
    this.menuTarget.classList.remove("pointer-events-none", "opacity-0")
    this.menuTarget.classList.add("pointer-events-auto", "opacity-100")

    // Stagger-animate each item upward
    this.itemTargets.forEach((item, i) => {
      item.style.transitionDelay = `${i * 50}ms`
      item.classList.remove("opacity-0", "translate-y-4")
      item.classList.add("opacity-100", "translate-y-0")
    })

    // Rotate + icon into ×
    this.iconTarget.classList.add("rotate-45")

    // Listen for outside click with a slight delay so this very click doesn't trigger it
    setTimeout(() => {
      document.addEventListener("click", this._handleOutsideClick)
    }, 10)
  }

  close() {
    this.isOpen = false

    // Reverse item animations
    this.itemTargets.forEach((item) => {
      item.style.transitionDelay = "0ms"
      item.classList.add("opacity-0", "translate-y-4")
      item.classList.remove("opacity-100", "translate-y-0")
    })

    // Restore + icon
    this.iconTarget.classList.remove("rotate-45")

    // Hide menu after transition
    setTimeout(() => {
      if (!this.isOpen) {
        this.menuTarget.classList.add("pointer-events-none", "opacity-0")
        this.menuTarget.classList.remove("pointer-events-auto", "opacity-100")
      }
    }, 250)

    document.removeEventListener("click", this._handleOutsideClick)
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}
