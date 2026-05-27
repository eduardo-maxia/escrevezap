import { Controller } from "@hotwired/stimulus"

// Reads flash type/message from data attributes and fires a Notyf toast.
// The element is immediately removed from the DOM (invisible).
//
// Usage (server-rendered):
//   <span data-controller="toast"
//         data-toast-type-value="notice"
//         data-toast-message-value="Salvo com sucesso!"></span>

export default class extends Controller {
  static values = { type: String, message: String }

  connect() {
    const notyf = window.__notyf
    if (!notyf || !this.messageValue) return

    if (this.typeValue === "alert") {
      notyf.error(this.messageValue)
    } else {
      notyf.success(this.messageValue)
    }

    this.element.remove()
  }
}
