import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.showModal()
    this.element.addEventListener("click", this.#backdropClose)
    this.element.addEventListener("close", this.#onNativeClose)
  }

  disconnect() {
    this.element.removeEventListener("click", this.#backdropClose)
    this.element.removeEventListener("close", this.#onNativeClose)
  }

  close() {
    this.element.close()
  }

  // Click anywhere on the backdrop (outside the dialog box) → close
  #backdropClose = (e) => {
    const rect = this.element.getBoundingClientRect()
    if (
      e.clientX < rect.left || e.clientX > rect.right ||
      e.clientY < rect.top  || e.clientY > rect.bottom
    ) {
      this.element.close()
    }
  }

  // After the dialog closes (ESC or programmatic), empty the frame
  // so it's ready for the next open without stale content
  #onNativeClose = () => {
    const frame = document.getElementById("modal")
    if (frame) frame.innerHTML = ""
  }
}
