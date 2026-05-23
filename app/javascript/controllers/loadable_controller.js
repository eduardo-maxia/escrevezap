import { Controller } from "@hotwired/stimulus"

// Loading-state controller for buttons.
//
// Attach to any <button> (or a wrapping form) to swap the button's content
// with an inline spinner the moment the user submits / clicks. Restores the
// original markup on `turbo:submit-end` so failed submissions return to a
// usable state.
//
// Examples:
//   <button data-controller="loadable"
//           data-loadable-loading-text-value="Enviando...">
//     Enviar
//   </button>
//
//   <%= button_to "Entrar", path, data: {
//         controller: "loadable",
//         "loadable-loading-text-value": "Entrando..."
//       } %>
//
// Values:
//   loading-text  — text shown next to the spinner (default: keeps original text)
//   spinner-only  — true  → render only a spinner (no text). Useful for icon buttons.
export default class extends Controller {
  static values = {
    loadingText: { type: String, default: "" },
    spinnerOnly: { type: Boolean, default: false }
  }

  connect() {
    this.form          = this.element.closest("form")
    this.originalHTML  = this.element.innerHTML
    this.loading       = false

    this._onStart = this.start.bind(this)
    this._onEnd   = this.stop.bind(this)

    if (this.form) {
      this.form.addEventListener("submit",            this._onStart)
      this.form.addEventListener("turbo:submit-start", this._onStart)
      this.form.addEventListener("turbo:submit-end",   this._onEnd)
    } else {
      this.element.addEventListener("click", this._onStart)
    }

    // If user navigates back via bfcache, reset the button.
    this._onPageShow = (e) => { if (e.persisted) this.stop() }
    window.addEventListener("pageshow", this._onPageShow)
  }

  disconnect() {
    if (this.form) {
      this.form.removeEventListener("submit",            this._onStart)
      this.form.removeEventListener("turbo:submit-start", this._onStart)
      this.form.removeEventListener("turbo:submit-end",   this._onEnd)
    } else {
      this.element.removeEventListener("click", this._onStart)
    }
    window.removeEventListener("pageshow", this._onPageShow)
  }

  start() {
    if (this.loading) return
    if (this.element.disabled) return  // skip if already disabled (e.g. invalid form)
    this.loading = true

    const label = this.spinnerOnlyValue
      ? ""
      : (this.loadingTextValue || this.element.textContent.trim())

    this.element.innerHTML = `
      <span class="btn-spinner" aria-hidden="true"></span>
      ${label ? `<span>${label}</span>` : ""}
    `.trim()

    this.element.setAttribute("aria-busy", "true")
    // Disable AFTER innerHTML swap so the form still submits this button's name/value.
    requestAnimationFrame(() => { this.element.disabled = true })
  }

  stop() {
    if (!this.loading) return
    this.loading = false
    this.element.disabled = false
    this.element.removeAttribute("aria-busy")
    this.element.innerHTML = this.originalHTML
  }
}
