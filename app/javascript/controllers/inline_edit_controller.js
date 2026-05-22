import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view", "editor", "field"]

  edit() {
    this.viewTarget.classList.add("hidden")
    this.editorTarget.classList.remove("hidden")
    if (this.hasFieldTarget) this.fieldTarget.focus()
  }

  cancel() {
    this.editorTarget.classList.add("hidden")
    this.viewTarget.classList.remove("hidden")
  }

  // Used when the controller element itself is the form (e.g. status auto-submit)
  submit() {
    this.element.requestSubmit()
  }
}
