import { Controller } from "@hotwired/stimulus"

// Countdown for the "resend code" button.
// Disables the button + shows "Reenviar em Ns" until seconds elapse,
// then swaps to an enabled "Reenviar código" button.
export default class extends Controller {
  static targets = ["cooldown", "countdown", "button"]
  static values  = { seconds: Number }

  connect() {
    this.remaining = this.secondsValue || 0
    if (this.remaining > 0) this.tick()
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  tick() {
    this.update()
    this.timer = setInterval(() => {
      this.remaining -= 1
      this.update()
      if (this.remaining <= 0) {
        clearInterval(this.timer)
        this.cooldownTarget.classList.add("hidden")
        if (this.hasButtonTarget) {
          this.buttonTarget.classList.remove("hidden")
          this.buttonTarget.disabled = false
        }
      }
    }, 1000)
  }

  update() {
    if (this.hasCountdownTarget) this.countdownTarget.textContent = this.remaining
  }
}
