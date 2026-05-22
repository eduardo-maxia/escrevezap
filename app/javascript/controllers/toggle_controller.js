import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }

  show() {
    this.contentTarget.classList.remove("hidden")
  }

  hide() {
    this.contentTarget.classList.add("hidden")
  }
}
