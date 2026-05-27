import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.showModal()

    // Close on backdrop click
    this._onBackdropClick = (e) => {
      const rect = this.element.getBoundingClientRect()
      const outside =
        e.clientX < rect.left  || e.clientX > rect.right ||
        e.clientY < rect.top   || e.clientY > rect.bottom
      if (outside) this.close()
    }
    this.element.addEventListener("click", this._onBackdropClick)

    // Clear the turbo-frame when dialog is closed (ESC or backdrop)
    this._onClose = () => this._clearFrame()
    this.element.addEventListener("close", this._onClose)
  }

  disconnect() {
    this.element.removeEventListener("click", this._onBackdropClick)
    this.element.removeEventListener("close", this._onClose)
  }

  close() {
    this.element.close()
    this._clearFrame()
  }

  _clearFrame() {
    const frame = document.getElementById("modal")
    if (frame) frame.innerHTML = ""
  }
}
