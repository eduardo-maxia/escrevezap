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
      if (!resp.ok || data.error) {
        this.#setResult(null, null)
      } else {
        this.#setResult(data.exists, data.exists ? data.picture_url : null)
      }
    } catch {
      this.#clearCheck()
    }
  }

  #clearCheck() {
    this.phoneCheckTarget.className = "hidden"
    this.phoneCheckTarget.innerHTML = ""
    this.#setSubmitEnabled(false)
  }

  #setLoading() {
    this.phoneCheckTarget.className = "text-xs mt-2 text-(--color-text-muted)"
    this.phoneCheckTarget.innerHTML = "Verificando..."
    this.#setSubmitEnabled(false)
  }

  #setResult(exists, pictureUrl) {
    if (exists === true) {
      const formatted = this.iti
        ? this.iti.getNumber(window.intlTelInputUtils?.numberFormat?.INTERNATIONAL)
        : ""
      const avatarHtml = pictureUrl
        ? `<img src="${pictureUrl}" class="w-10 h-10 rounded-full object-cover flex-shrink-0" alt="">`
        : `<span class="w-10 h-10 rounded-full bg-(--color-success) bg-opacity-20 flex items-center justify-center flex-shrink-0"><i class="ph-fill ph-whatsapp-logo text-xl text-(--color-success)"></i></span>`
      this.phoneCheckTarget.className = "mt-2"
      this.phoneCheckTarget.innerHTML = `
        <div class="flex items-center gap-3 px-3 py-2.5 rounded-xl bg-(--color-success-light) border border-(--color-success) border-opacity-20">
          ${avatarHtml}
          <div class="min-w-0">
            <p class="text-xs font-semibold text-(--color-success) leading-tight">WhatsApp confirmado</p>
            <p class="text-xs text-(--color-success) opacity-70 truncate mt-0.5">${formatted}</p>
          </div>
        </div>`
    } else if (exists === false) {
      this.phoneCheckTarget.className = "text-xs mt-2 text-(--color-warning) font-medium"
      this.phoneCheckTarget.innerHTML = "⚠ Número não encontrado no WhatsApp"
    } else {
      this.phoneCheckTarget.className = "text-xs mt-2 text-(--color-text-muted)"
      this.phoneCheckTarget.innerHTML = "Não foi possível verificar"
    }
    this.#setSubmitEnabled(exists === true)
  }

  #setSubmitEnabled(enabled) {
    if (!this.hasSubmitTarget) return
    this.submitTarget.disabled = !enabled
  }
}
