import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nameInput", "nameForm", "avatarForm", "emailSection", "emailForm"]

  connect() {
    this._savedName = this.nameInputTarget.value
  }

  // Auto-save name on blur — only if value actually changed
  autoSaveName() {
    const current = this.nameInputTarget.value.trim()
    if (current === this._savedName.trim()) return
    this._savedName = current
    this.nameFormTarget.requestSubmit()
  }

  // Auto-save avatar on file selection
  avatarChanged() {
    this.avatarFormTarget.requestSubmit()
  }

  // Show/hide the email change inline form
  toggleEmail(e) {
    e.preventDefault()
    const hidden = this.emailSectionTarget.classList.contains("hidden")
    this.emailSectionTarget.classList.toggle("hidden", !hidden)
    if (hidden) {
      this.emailSectionTarget.querySelector("input[type='email']")?.focus()
    }
  }
}
