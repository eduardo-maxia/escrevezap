import { Controller } from "@hotwired/stimulus"

// Apple-style 6-digit OTP input.
//
// Features:
//   • Auto-advance to next box on digit entry
//   • Backspace clears current; if already empty, moves focus back
//   • Arrow Left/Right navigation
//   • Paste of full code (any length up to 6) distributes across boxes
//   • Auto-submits the form once all boxes are filled
//   • Keeps a single hidden input synced with the joined value
//   • Only digits allowed
export default class extends Controller {
  static targets = ["boxes", "hidden", "submit"]
  static values  = { length: { type: Number, default: 4 } }

  connect() {
    this.boxes = Array.from(this.boxesTarget.querySelectorAll("input"))
    this.sync()
    // Focus first empty box on load.
    const firstEmpty = this.boxes.find((b) => !b.value)
    ;(firstEmpty || this.boxes[0]).focus()
  }

  // -------- Event handlers ---------------------------------------------------

  onInput(e) {
    const input = e.target
    if (!this.boxes.includes(input)) return

    // Strip non-digits, keep only the last typed digit.
    const digits = input.value.replace(/\D/g, "")
    input.value = digits.slice(-1)

    if (input.value) {
      this.advance(input)
    }
    this.sync()
  }

  onKeydown(e) {
    const input = e.target
    if (!this.boxes.includes(input)) return

    if (e.key === "Backspace") {
      if (input.value === "") {
        const prev = this.prevBox(input)
        if (prev) {
          e.preventDefault()
          prev.value = ""
          prev.focus()
          this.sync()
        }
      }
    } else if (e.key === "ArrowLeft") {
      const prev = this.prevBox(input)
      if (prev) { e.preventDefault(); prev.focus() }
    } else if (e.key === "ArrowRight") {
      const next = this.nextBox(input)
      if (next) { e.preventDefault(); next.focus() }
    } else if (e.key === "Enter") {
      // Let it submit naturally if complete; otherwise prevent.
      if (!this.complete) e.preventDefault()
    }
  }

  onPaste(e) {
    e.preventDefault()
    const text = (e.clipboardData || window.clipboardData).getData("text") || ""
    const digits = text.replace(/\D/g, "").slice(0, this.lengthValue).split("")
    if (digits.length === 0) return

    this.boxes.forEach((b, i) => { b.value = digits[i] || "" })

    // Focus the next empty box, or the last one if all filled.
    const nextEmpty = this.boxes.find((b) => !b.value)
    ;(nextEmpty || this.boxes[this.boxes.length - 1]).focus()
    this.sync()
  }

  onFocus(e) {
    if (this.boxes.includes(e.target)) e.target.select()
  }

  // -------- Helpers ----------------------------------------------------------

  advance(input) {
    const next = this.nextBox(input)
    if (next) next.focus()
  }

  nextBox(input) {
    const i = this.boxes.indexOf(input)
    return this.boxes[i + 1] || null
  }

  prevBox(input) {
    const i = this.boxes.indexOf(input)
    return this.boxes[i - 1] || null
  }

  get value() {
    return this.boxes.map((b) => b.value || "").join("")
  }

  get complete() {
    return this.value.length === this.lengthValue
  }

  sync() {
    if (this.hasHiddenTarget) this.hiddenTarget.value = this.value
    if (this.hasSubmitTarget) this.submitTarget.disabled = !this.complete

    // Auto-submit on completion.
    if (this.complete) {
      // Small timeout so the last keystroke renders before submit.
      setTimeout(() => this.element.requestSubmit?.() || this.element.submit(), 80)
    }
  }
}
