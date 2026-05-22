import { Controller } from "@hotwired/stimulus"

// intlTelInput is loaded via CDN (intlTelInputWithUtils.min.js) — no npm import needed
export default class extends Controller {
  static targets = ["input", "hidden", "phoneCheck", "submit"]

  static values = { checkWhatsappUrl: String }

  connect() {
    this.#whenItiReady().then((ready) => {
      if (!ready || !this.element.isConnected) return
      this.#init()
    })
  }

  #whenItiReady() {
    return new Promise((resolve) => {
      if (typeof window.intlTelInput === "function") return resolve(true)

      const start = Date.now()
      const timeoutMs = 8000
      this._waitTimer = setInterval(() => {
        if (typeof window.intlTelInput === "function") {
          clearInterval(this._waitTimer)
          this._waitTimer = null
          resolve(true)
        } else if (Date.now() - start > timeoutMs) {
          clearInterval(this._waitTimer)
          this._waitTimer = null
          console.warn("intlTelInput not found after waiting — CDN script may have failed to load")
          resolve(false)
        }
      }, 100)
    })
  }

  #init() {
    this.iti = window.intlTelInput(this.inputTarget, {
      initialCountry: "br",
      strictMode: true,
      autoPlaceholder: "polite",
    })

    // Sync hidden input on every change so submit always has the latest E.164 value
    this._sync = () => { this.hiddenTarget.value = this.iti.getNumber() }
    this.inputTarget.addEventListener("input", this._sync)
    this.inputTarget.addEventListener("countrychange", this._sync)
  }

  disconnect() {
    if (this._waitTimer) {
      clearInterval(this._waitTimer)
      this._waitTimer = null
    }
    if (this._sync) {
      this.inputTarget.removeEventListener("input", this._sync)
      this.inputTarget.removeEventListener("countrychange", this._sync)
    }
    this.iti?.destroy()
    clearTimeout(this._checkTimer)
  }

  // Called via data-action="submit->phone-input#syncHidden" as a final safety sync
  syncHidden() {
    if (this.iti) this.hiddenTarget.value = this.iti.getNumber()
  }

  // ── WhatsApp number check ─────────────────────────────────────────────

  checkPhone() {
    if (!this.hasCheckWhatsappUrlValue || !this.hasPhoneCheckTarget) return

    clearTimeout(this._checkTimer)
    const phone = this.iti ? this.iti.getNumber().replace(/\D/g, "") : this.inputTarget.value.replace(/\D/g, "")

    if (phone.length < 10) {
      this.#clearCheck()
      return
    }

    this.#setLoading()
    this._checkTimer = setTimeout(() => this.#doCheck(phone), 600)
  }

  async #doCheck(phone) {
    try {
      const url = `${this.checkWhatsappUrlValue}?phone=${encodeURIComponent(phone)}`
      const resp = await fetch(url, { headers: { "Accept": "application/json" } })
      const data = await resp.json()
      this.#setResult(!resp.ok || data.error ? null : data.exists)
    } catch {
      this.#clearCheck()
    }
  }

  #clearCheck() {
    this.phoneCheckTarget.className = "hidden"
    this.phoneCheckTarget.textContent = ""
    this.#setSubmitEnabled(false)
  }

  #setLoading() {
    this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-text-muted)"
    this.phoneCheckTarget.textContent = "Verificando..."
    this.#setSubmitEnabled(false)
  }

  #setResult(exists) {
    if (exists === true) {
      this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-success) font-medium"
      this.phoneCheckTarget.textContent = "✓ Número tem WhatsApp"
    } else if (exists === false) {
      this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-warning) font-medium"
      this.phoneCheckTarget.textContent = "⚠ Número não encontrado no WhatsApp"
    } else {
      this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-text-muted)"
      this.phoneCheckTarget.textContent = "Não foi possível verificar"
    }
    this.#setSubmitEnabled(exists === true)
  }

  #setSubmitEnabled(enabled) {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = !enabled
  }
}
