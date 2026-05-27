import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this._timer = setTimeout(() => this._dismiss(), 4500)
  }

  disconnect() {
    clearTimeout(this._timer)
  }

  dismiss() {
    this._dismiss()
  }

  _dismiss() {
    clearTimeout(this._timer)
    this.element.style.transition = "opacity 0.3s ease, transform 0.3s ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-6px)"
    setTimeout(() => this.element.remove(), 300)
  }
}
