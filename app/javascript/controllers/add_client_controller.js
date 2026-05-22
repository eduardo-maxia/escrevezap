import { Controller } from "@hotwired/stimulus"

// add-client controller — handles the 3-step add-client flow:
//   1. Search: debounced name search → dropdown (existing clients + "create new")
//   2a. Existing client selected → show badge, enable amount/date/submit
//   2b. New client mode → show name badge + phone input with WhatsApp check
//   3. Amount in centavos: user types digits only, display formatted as "123,45"
export default class extends Controller {
  static targets = [
    "searchSection", "searchInput", "dropdown",
    "selectedSection", "selectedLabel", "clientIdHidden",
    "newSection", "newNameLabel", "newNameHidden",
    "phoneInput", "phoneHidden", "phoneCheck",
    "extraFields",
    "amountDisplay", "amountHidden",
    "submitBtn",
  ]

  static values = {
    searchUrl: String,
    checkWhatsappUrl: String,
  }

  // ── Lifecycle ──────────────────────────────────────────────────────

  #state = "idle"  // idle | selected | new
  #iti   = null
  #searchTimer = null
  #checkTimer  = null

  disconnect() {
    clearTimeout(this.#searchTimer)
    clearTimeout(this.#checkTimer)
    this.#iti?.destroy()
    this.#iti = null
  }

  // ── Search ─────────────────────────────────────────────────────────

  onInput() {
    if (this.#state !== "idle") return
    const q = this.searchInputTarget.value.trim()
    clearTimeout(this.#searchTimer)
    if (q.length < 1) { this.#closeDropdown(); return }
    this.#searchTimer = setTimeout(() => this.#fetchResults(q), 500)
  }

  onKeydown(event) {
    if (event.key === "Escape") { this.#closeDropdown(); return }
    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.dropdownTarget.querySelector("li")?.focus()
    }
    if (event.key === "Tab") {
      // Tab away → treat as "create new" if something was typed
      const q = this.searchInputTarget.value.trim()
      if (q.length >= 1 && this.#state === "idle") {
        event.preventDefault()
        this.#closeDropdown()
        this.#enterNewMode(q)
      }
    }
  }

  onBlur() {
    // Delay to let mousedown on dropdown items fire first
    setTimeout(() => {
      if (this.#state !== "idle") return
      this.#closeDropdown()
      const q = this.searchInputTarget.value.trim()
      if (q.length >= 1) this.#enterNewMode(q)
    }, 200)
  }

  async #fetchResults(q) {
    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(q)}`
      const resp = await fetch(url, {
        headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" },
      })
      if (!resp.ok) return
      const clients = await resp.json()
      this.#renderDropdown(clients, q)
    } catch { /* ignore network errors */ }
  }

  #renderDropdown(clients, q) {
    const ul = this.dropdownTarget
    ul.innerHTML = ""

    if (clients.length > 0) {
      clients.forEach(client => {
        const li = document.createElement("li")
        li.tabIndex = 0
        const initials = client.name.split(" ").slice(0, 2).map(w => w[0]).join("").toUpperCase()
        li.innerHTML = `
          <div class="flex items-center gap-3 px-3 py-2.5 hover:bg-(--color-surface-raised) cursor-pointer transition-colors">
            <div class="w-7 h-7 rounded-full bg-(--color-brand-subtle) flex items-center justify-center flex-shrink-0 text-xs font-bold text-(--color-brand)">${initials}</div>
            <div class="min-w-0 flex-1">
              <p class="text-sm font-medium text-(--color-text) truncate">${this.#escHtml(client.name)}</p>
              ${client.phone ? `<p class="text-xs text-(--color-text-muted)">${this.#escHtml(client.phone)}</p>` : ""}
            </div>
          </div>
        `
        li.addEventListener("mousedown", (e) => { e.preventDefault(); this.#selectClient(client) })
        li.addEventListener("keydown",   (e) => { if (e.key === "Enter") this.#selectClient(client) })
        ul.appendChild(li)
      })
    }

    // "Create new" option always at the bottom
    const liNew = document.createElement("li")
    liNew.tabIndex = 0
    liNew.innerHTML = `
      <div class="flex items-center gap-3 px-3 py-2.5 hover:bg-(--color-surface-raised) cursor-pointer transition-colors ${clients.length > 0 ? "border-t border-(--color-border)" : ""}">
        <div class="w-7 h-7 rounded-full bg-(--color-surface-raised) flex items-center justify-center flex-shrink-0">
          <i class="ph ph-user-plus text-sm text-(--color-brand)"></i>
        </div>
        <div>
          <p class="text-sm font-semibold text-(--color-brand)">Criar novo cliente</p>
          <p class="text-xs text-(--color-text-muted) truncate max-w-xs">"${this.#escHtml(q)}"</p>
        </div>
      </div>
    `
    liNew.addEventListener("mousedown", (e) => { e.preventDefault(); this.#enterNewMode(q) })
    liNew.addEventListener("keydown",   (e) => { if (e.key === "Enter") this.#enterNewMode(q) })
    ul.prepend(liNew)

    ul.classList.remove("hidden")
  }

  #closeDropdown() {
    this.dropdownTarget.classList.add("hidden")
  }

  // ── Select existing client ─────────────────────────────────────────

  #selectClient(client) {
    this.#state = "selected"
    this.#closeDropdown()

    this.clientIdHiddenTarget.value = client.id
    this.selectedLabelTarget.textContent = [client.name, client.phone].filter(Boolean).join("  ·  ")

    this.searchSectionTarget.classList.add("hidden")
    this.selectedSectionTarget.classList.remove("hidden")
    this.newSectionTarget.classList.add("hidden")
    this.extraFieldsTarget.classList.remove("hidden")
    this.submitBtnTarget.disabled = false
    this.amountDisplayTarget.focus()
  }

  clearSelection() {
    this.#state = "idle"

    // Reset hidden inputs
    if (this.hasClientIdHiddenTarget) this.clientIdHiddenTarget.value = ""
    if (this.hasNewNameHiddenTarget)  this.newNameHiddenTarget.value  = ""
    if (this.hasPhoneHiddenTarget)    this.phoneHiddenTarget.value    = ""
    if (this.hasAmountHiddenTarget)   this.amountHiddenTarget.value   = ""
    if (this.hasAmountDisplayTarget)  this.amountDisplayTarget.value  = ""

    // Destroy phone picker if was init'd
    if (this.#iti) { this.#iti.destroy(); this.#iti = null }
    if (this.hasPhoneCheckTarget) {
      this.phoneCheckTarget.className = "hidden"
      this.phoneCheckTarget.textContent = ""
    }

    this.searchInputTarget.value = ""
    this.searchSectionTarget.classList.remove("hidden")
    this.selectedSectionTarget.classList.add("hidden")
    this.newSectionTarget.classList.add("hidden")
    this.extraFieldsTarget.classList.add("hidden")
    this.submitBtnTarget.disabled = true
    this.#closeDropdown()
    this.searchInputTarget.focus()
  }

  // ── New client mode ────────────────────────────────────────────────

  #enterNewMode(name) {
    this.#state = "new"
    this.#closeDropdown()

    this.newNameHiddenTarget.value = name
    this.newNameLabelTarget.textContent = name

    this.searchSectionTarget.classList.add("hidden")
    this.newSectionTarget.classList.remove("hidden")
    this.selectedSectionTarget.classList.add("hidden")
    this.extraFieldsTarget.classList.remove("hidden")
    this.submitBtnTarget.disabled = false  // always allowed; WhatsApp check is informational

    this.#initPhoneInput()
    this.phoneInputTarget.focus()
  }

  #initPhoneInput() {
    if (this.#iti) return
    if (typeof window.intlTelInput === "function") {
      this.#buildIti()
      return
    }
    // CDN script may not be loaded yet — poll briefly.
    const start = Date.now()
    const timeoutMs = 8000
    const timer = setInterval(() => {
      if (typeof window.intlTelInput === "function") {
        clearInterval(timer)
        if (!this.#iti && this.hasPhoneInputTarget) this.#buildIti()
      } else if (Date.now() - start > timeoutMs) {
        clearInterval(timer)
        console.warn("intlTelInput not found after waiting — CDN script may have failed to load")
      }
    }, 100)
  }

  #buildIti() {
    this.#iti = window.intlTelInput(this.phoneInputTarget, {
      initialCountry: "br",
      strictMode: true,
      autoPlaceholder: "polite",
    })
  }

  // ── WhatsApp check ─────────────────────────────────────────────────

  onPhoneInput() {
    if (!this.#iti) return
    // Always sync — phone is stored regardless of WhatsApp verification
    this.phoneHiddenTarget.value = this.#iti.getNumber()
    clearTimeout(this.#checkTimer)
    const phone = this.#iti.getNumber().replace(/\D/g, "")
    if (phone.length < 10) { this.#clearPhoneCheck(); return }
    this.#setPhoneLoading()
    this.#checkTimer = setTimeout(() => this.#doPhoneCheck(phone), 600)
  }

  async #doPhoneCheck(phone) {
    try {
      const url = `${this.checkWhatsappUrlValue}?phone=${encodeURIComponent(phone)}`
      const resp = await fetch(url, { headers: { "Accept": "application/json" } })
      const data = await resp.json()
      if (!resp.ok || data.error) { this.#setPhoneResult(null); return }
      this.#setPhoneResult(data.exists)
    } catch {
      this.#clearPhoneCheck()
    }
  }

  #clearPhoneCheck() {
    this.phoneCheckTarget.className = "hidden"
    this.phoneCheckTarget.textContent = ""
  }

  #setPhoneLoading() {
    this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-text-muted)"
    this.phoneCheckTarget.textContent = "Verificando..."
  }

  // WhatsApp result is purely informational — never blocks submission
  #setPhoneResult(exists) {
    if (exists === true) {
      this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-success) font-medium"
      this.phoneCheckTarget.textContent = "✓ Tem WhatsApp — receberá lembretes"
    } else if (exists === false) {
      this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-text-muted) font-medium"
      this.phoneCheckTarget.textContent = "Sem WhatsApp — não receberá lembretes automáticos"
    } else {
      this.phoneCheckTarget.className = "text-xs mt-1.5 text-(--color-text-muted)"
      this.phoneCheckTarget.textContent = "Não foi possível verificar o WhatsApp"
    }
  }

  // ── Amount (centavos input) ────────────────────────────────────────
  // User types digits only. Last 2 digits = cents, rest = reais.
  // Example: typing "12345" → display "123,45", hidden "123.45"

  onAmountInput() {
    const digits = this.amountDisplayTarget.value.replace(/\D/g, "")
    const cents = parseInt(digits || "0", 10)

    if (cents === 0) {
      this.amountDisplayTarget.value = ""
      this.amountHiddenTarget.value  = ""
      return
    }

    const amount = cents / 100
    this.amountDisplayTarget.value = amount.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
    this.amountHiddenTarget.value  = amount.toFixed(2)
  }

  // ── Utils ──────────────────────────────────────────────────────────

  #escHtml(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
  }
}
