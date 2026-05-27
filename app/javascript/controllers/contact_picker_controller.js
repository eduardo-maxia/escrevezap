import { Controller } from "@hotwired/stimulus"

// Full-screen contact picker — opens as a fixed overlay mimicking the
// WhatsApp contact-list screen. Contacts are fetched eagerly on connect.

export default class extends Controller {
  static targets = [
    // Overlay & internal elements
    "overlay", "search", "list", "loading", "empty", "count",
    // Form fields
    "phone", "name",
    // Page-level: trigger button + selected card
    "trigger", "selectedCard", "selectedName", "selectedPhone"
  ]
  static values = { url: String }

  connect() {
    this._contacts = []
    this._fetch()
  }

  disconnect() {
    this._unlockScroll()
  }

  // ── Overlay open / close ────────────────────────────────────────────────

  openPicker(event) {
    event?.preventDefault()
    this.overlayTarget.classList.remove("hidden")
    this._lockScroll()
    // Reset search
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      requestAnimationFrame(() => this.searchTarget.focus())
    }
    this._render(this._contacts)
  }

  closePicker(event) {
    event?.preventDefault()
    this.overlayTarget.classList.add("hidden")
    this._unlockScroll()
  }

  _lockScroll()   { document.body.style.overflow = "hidden" }
  _unlockScroll() { document.body.style.overflow = "" }

  // ── Data fetching ───────────────────────────────────────────────────────

  async _fetch() {
    if (this.hasLoadingTarget) this.loadingTarget.classList.remove("hidden")
    if (this.hasListTarget)    this.listTarget.innerHTML = ""

    try {
      const resp = await fetch(this.urlValue, {
        headers: { "Accept": "application/json", "X-Requested-With": "XMLHttpRequest" }
      })
      const data = await resp.json()
      this._contacts = data.contacts || []
    } catch (_) {
      this._contacts = []
    } finally {
      if (this.hasLoadingTarget) this.loadingTarget.classList.add("hidden")
      this._updateCount()
      this._render(this._contacts)
    }
  }

  _updateCount() {
    if (!this.hasCountTarget) return
    const n = this._contacts.length
    this.countTarget.textContent = n > 0 ? `${n} contatos` : ""
  }

  // ── Search / filter ─────────────────────────────────────────────────────

  filter() {
    const q = this.searchTarget.value.trim().toLowerCase()
    if (!q) { this._render(this._contacts); return }

    const scored = this._contacts
      .map(c => ({ c, score: this._score(c, q) }))
      .filter(({ score }) => score > 0)
      .sort((a, b) => b.score - a.score)
      .map(({ c }) => c)

    this._render(scored, true) // flat — no alpha groups during search
  }

  // Score a contact against a query string (higher = better match).
  _score(contact, q) {
    const name  = (contact.name  || "").toLowerCase()
    const phone = (contact.phone || "").toLowerCase()

    // Exact full match
    if (name === q || phone === q) return 100

    // Starts with query
    if (name.startsWith(q))  return 80
    if (phone.startsWith(q)) return 70

    // Word boundary — any word in the name starts with query
    const words = name.split(/\s+/)
    if (words.some(w => w.startsWith(q))) return 60

    // Contains query
    if (name.includes(q))  return 40
    if (phone.includes(q)) return 30

    // Fuzzy: all chars of query appear in order in name or phone
    if (this._fuzzy(name, q))  return 15
    if (this._fuzzy(phone, q)) return 10

    return 0
  }

  // Returns true if all chars in `pattern` appear in `str` in order.
  _fuzzy(str, pattern) {
    let si = 0
    for (let i = 0; i < pattern.length; i++) {
      si = str.indexOf(pattern[i], si)
      if (si === -1) return false
      si++
    }
    return true
  }

  // ── Selection ───────────────────────────────────────────────────────────

  select(event) {
    const btn   = event.currentTarget
    const phone = btn.dataset.phone
    const name  = btn.dataset.name || ""

    // Fill hidden form fields
    this.phoneTarget.value = phone
    if (this.hasNameTarget && !this.nameTarget.value) {
      this.nameTarget.value = name
    }

    // Update selected card
    if (this.hasSelectedNameTarget)  this.selectedNameTarget.textContent  = name || phone
    if (this.hasSelectedPhoneTarget) this.selectedPhoneTarget.textContent = name ? phone : ""
    if (this.hasSelectedCardTarget)  this.selectedCardTarget.classList.remove("hidden")
    if (this.hasTriggerTarget)       this.triggerTarget.classList.add("hidden")

    this.closePicker()
  }

  // Manual phone number fallback
  manualPhone(event) {
    const phone = event.currentTarget.value.replace(/\D/g, "")
    this.phoneTarget.value = phone
    if (this.hasSelectedNameTarget)  this.selectedNameTarget.textContent  = phone
    if (this.hasSelectedPhoneTarget) this.selectedPhoneTarget.textContent = ""
    if (this.hasSelectedCardTarget)  this.selectedCardTarget.classList.toggle("hidden", !phone)
    if (this.hasTriggerTarget)       this.triggerTarget.classList.toggle("hidden", !!phone)
  }

  // ── Rendering ───────────────────────────────────────────────────────────

  _render(contacts, flat = false) {
    if (!this.hasListTarget) return

    if (contacts.length === 0) {
      this.listTarget.innerHTML = ""
      if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
      return
    }

    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")

    if (flat) {
      // During search: flat list, sorted by score, no alpha headers
      this.listTarget.innerHTML = `<ul>${contacts.map(c => this._itemHtml(c)).join("")}</ul>`
      return
    }

    // Grouped by first letter — numbers/symbols go under "#"
    const groups = {}
    contacts.forEach(c => {
      const letter = (c.name || c.phone || "#").charAt(0).toUpperCase()
      const key    = /[A-ZÁÀÂÃÉÈÊÍÌÓÒÔÕÚÙÛÇ]/.test(letter) ? letter : "#"
      ;(groups[key] = groups[key] || []).push(c)
    })

    const sorted = Object.keys(groups).sort((a, b) => {
      if (a === "#") return 1
      if (b === "#") return -1
      return a.localeCompare(b, "pt-BR")
    })

    this.listTarget.innerHTML = sorted.map(letter => `
      <div>
        <div class="sticky top-0 z-10 px-4 py-1 bg-(--color-surface-muted)">
          <span class="text-xs font-bold text-(--color-brand) tracking-wider">${letter}</span>
        </div>
        <ul>
          ${groups[letter].map(c => this._itemHtml(c)).join("")}
        </ul>
      </div>
    `).join("")
  }

  _itemHtml(c) {
    const initials   = (c.name || c.phone || "?").charAt(0).toUpperCase()
    const colorIndex = initials.charCodeAt(0) % this._avatarColors.length
    const [bg, fg]   = this._avatarColors[colorIndex]
    const phone      = this._esc(c.phone)
    const name       = this._esc(c.name || "")
    const label      = name || phone

    return `
      <li class="contact-item-sep">
        <button type="button"
                class="w-full flex items-center gap-3 px-4 hover:bg-(--color-brand-subtle) active:bg-(--color-brand-light) transition-colors text-left"
                data-action="click->contact-picker#select"
                data-phone="${phone}"
                data-name="${name}">
          <div class="flex-shrink-0 w-9 h-9 rounded-full flex items-center justify-center font-semibold text-sm select-none"
               style="background-color:${bg};color:${fg}">
            ${initials}
          </div>
          <div class="flex-1 min-w-0 py-3">
            <p class="text-sm font-semibold text-(--color-text) truncate">${label}</p>
            ${name ? `<p class="text-xs text-(--color-text-muted) truncate mt-0.5">${phone}</p>` : ""}
          </div>
        </button>
      </li>
    `
  }

  get _avatarColors() {
    return [
      ["#DBEAFE", "#1E40AF"],
      ["#D1FAE5", "#065F46"],
      ["#EDE9FE", "#5B21B6"],
      ["#FEF3C7", "#B45309"],
      ["#FCE7F3", "#9D174D"],
      ["#E0E7FF", "#3730A3"],
      ["#CCFBF1", "#0F766E"],
      ["#FFEDD5", "#C2410C"],
      ["#FFE4E6", "#BE123C"],
      ["#CFFAFE", "#0E7490"],
    ]
  }

  _esc(str) {
    return String(str)
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
  }
}
