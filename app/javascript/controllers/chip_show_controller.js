import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Controls the Chip#show page in the no-campaigns flow.
// - Always subscribes to ChipStatusChannel
// - Renders one of: connected | idle | connecting | qr | failed
// - "Conectar agora" starts a session; we wait up to 30s for scan_qr_code/working
export default class extends Controller {
  static targets = [
    "statusPill",
    "connectedPanel", "idlePanel", "connectingPanel", "qrSection", "failedPanel",
    "connectingMessage", "errorMessage",
    "qrImage", "qrSpinner",
    "qrTab", "codeTab", "qrPanel", "codePanel",
    "phoneForm", "phoneInput", "requestCodeBtn", "codeError",
    "codeDisplay", "codeBoxes", "countdown", "copyBtn"
  ]

  static values = {
    chipId:           Number,
    initialStatus:    String,
    startUrl:         String,
    qrUrl:            String,
    requestCodeUrl:   String
  }

  connect() {
    this._currentCode = null
    this.cable = createConsumer()
    this.subscription = this.cable.subscriptions.create(
      { channel: "ChipStatusChannel", chip_id: this.chipIdValue },
      {
        connected:    () => console.log("[chip-show] cable connected for chip", this.chipIdValue),
        disconnected: () => console.log("[chip-show] cable disconnected"),
        rejected:     () => console.warn("[chip-show] subscription rejected"),
        received:     (data) => {
          console.log("[chip-show] received:", data)
          this.#handleStatus(data)
        }
      }
    )
    this.#renderForStatus(this.initialStatusValue, { initial: true })
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.cable?.disconnect()
    clearInterval(this.countdownTimer)
    clearTimeout(this.connectingTimeout)
  }

  // ── Actions ─────────────────────────────────────────────────────────

  async startConnect() {
    this.#renderForStatus("starting")
    try {
      const resp = await this.#post(this.startUrlValue, {})
      if (!resp.ok) throw new Error("Falha ao iniciar sessão.")
      // wait for cable to push next status
    } catch (e) {
      this.#showFailed(e.message || "Erro ao iniciar sessão.")
    }
  }

  retry() {
    this.#renderForStatus("pending")
  }

  switchToQr() {
    this.qrPanelTarget.classList.remove("hidden")
    this.codePanelTarget.classList.add("hidden")
    this.qrTabTarget.classList.add("bg-(--color-brand)", "text-(--color-text-inverse)")
    this.qrTabTarget.classList.remove("text-(--color-text-muted)")
    this.codeTabTarget.classList.remove("bg-(--color-brand)", "text-(--color-text-inverse)")
    this.codeTabTarget.classList.add("text-(--color-text-muted)")
  }

  switchToCode() {
    this.codePanelTarget.classList.remove("hidden")
    this.qrPanelTarget.classList.add("hidden")
    this.codeTabTarget.classList.add("bg-(--color-brand)", "text-(--color-text-inverse)")
    this.codeTabTarget.classList.remove("text-(--color-text-muted)")
    this.qrTabTarget.classList.remove("bg-(--color-brand)", "text-(--color-text-inverse)")
    this.qrTabTarget.classList.add("text-(--color-text-muted)")
  }

  async requestCode() {
    const phone = this.phoneInputTarget.value.replace(/\D/g, "")
    if (!phone) { this.#showCodeError("Informe seu número de WhatsApp."); return }

    this.requestCodeBtnTarget.disabled = true
    this.requestCodeBtnTarget.textContent = "Aguarde..."
    this.codeErrorTarget.classList.add("hidden")

    try {
      const resp = await this.#post(this.requestCodeUrlValue, { phone_number: phone })
      const data = await resp.json()
      if (!resp.ok) {
        this.#showCodeError(data.error || "Erro ao gerar código.")
        this.requestCodeBtnTarget.disabled = false
        this.requestCodeBtnTarget.textContent = "Gerar código"
        return
      }
      this.#showCode(data.code)
    } catch {
      this.#showCodeError("Erro de conexão. Tente novamente.")
      this.requestCodeBtnTarget.disabled = false
      this.requestCodeBtnTarget.textContent = "Gerar código"
    }
  }

  resetCode() {
    clearInterval(this.countdownTimer)
    this.codeDisplayTarget.classList.add("hidden")
    this.phoneFormTarget.classList.remove("hidden")
    this.phoneInputTarget.value = ""
    this.requestCodeBtnTarget.disabled = false
    this.requestCodeBtnTarget.textContent = "Gerar código"
  }

  async copyCode() {
    if (!this._currentCode) return
    try {
      await navigator.clipboard.writeText(this._currentCode)
      const btn = this.copyBtnTarget
      const original = btn.innerHTML
      btn.innerHTML = '<i class="ph ph-check text-sm"></i> Copiado!'
      btn.disabled = true
      setTimeout(() => { btn.innerHTML = original; btn.disabled = false }, 2000)
    } catch { /* no-op */ }
  }

  // ── State machine ───────────────────────────────────────────────────

  #handleStatus({ status }) {
    if (!status) return
    // If we reach working, reload to refresh header/profile picture/number.
    if (status === "working" && this.initialStatusValue !== "working") {
      window.location.reload()
      return
    }
    this.#renderForStatus(status)
  }

  #renderForStatus(status, { initial = false } = {}) {
    clearTimeout(this.connectingTimeout)
    this.#hideAllPanels()

    switch (status) {
      case "working":
        this.connectedPanelTarget.classList.remove("hidden")
        this.#setPill("Conectado", "success", "ph-check-circle")
        break

      case "scan_qr_code":
        this.qrSectionTarget.classList.remove("hidden")
        this.#setPill("Aguardando QR", "warning", "ph-qr-code")
        this.#fetchQr()
        break

      case "starting":
        this.connectingPanelTarget.classList.remove("hidden")
        this.#setPill("Iniciando...", "warning", "ph-circle-dashed")
        this.#armConnectingTimeout()
        break

      case "failed":
        this.#showFailed("A sessão falhou ao iniciar.")
        break

      default: // pending, stopped, unknown
        this.idlePanelTarget.classList.remove("hidden")
        this.#setPill(status === "stopped" ? "Parado" : "Não configurado", "muted", "ph-plug")
    }
  }

  #showFailed(message) {
    this.#hideAllPanels()
    clearTimeout(this.connectingTimeout)
    this.failedPanelTarget.classList.remove("hidden")
    if (this.hasErrorMessageTarget && message) this.errorMessageTarget.textContent = message
    this.#setPill("Falha", "danger", "ph-warning-circle")
  }

  #armConnectingTimeout() {
    clearTimeout(this.connectingTimeout)
    this.connectingTimeout = setTimeout(() => {
      this.#showFailed("Demorou demais para iniciar. Tente novamente.")
    }, 30000)
  }

  #hideAllPanels() {
    const panels = [
      "connectedPanel", "idlePanel", "connectingPanel", "qrSection", "failedPanel"
    ]
    panels.forEach(name => {
      const t = `has${name[0].toUpperCase() + name.slice(1)}Target`
      if (this[t]) this[`${name}Target`].classList.add("hidden")
    })
  }

  // ── QR fetch ────────────────────────────────────────────────────────

  async #fetchQr() {
    try {
      const resp = await fetch(this.qrUrlValue, { headers: { "Accept": "application/json" } })
      if (!resp.ok) {
        setTimeout(() => this.#fetchQr(), 2000)
        return
      }
      const { data, mimetype } = await resp.json()
      this.qrImageTarget.src = `data:${mimetype};base64,${data}`
      this.qrSpinnerTarget.classList.add("hidden")
      this.qrImageTarget.classList.remove("hidden")
    } catch {
      setTimeout(() => this.#fetchQr(), 2000)
    }
  }

  // ── Pairing code display ────────────────────────────────────────────

  #showCode(code) {
    this._currentCode = code
    const chars = code.replace(/-/g, "").split("")
    const boxCls = [
      "w-10 h-12 rounded-xl border-2 border-(--color-brand)",
      "bg-(--color-brand-subtle) flex items-center justify-center",
      "font-bold text-xl text-(--color-brand) select-all"
    ].join(" ")
    const sep = `<div class="flex items-center px-1 text-lg font-semibold text-(--color-text-subtle) select-none">–</div>`
    const boxes = chars.map(c => `<div class="${boxCls}">${c}</div>`)
    boxes.splice(4, 0, sep)
    this.codeBoxesTarget.innerHTML = boxes.join("")

    this.phoneFormTarget.classList.add("hidden")
    this.codeDisplayTarget.classList.remove("hidden")
    this.#startCountdown(5 * 60)
  }

  #startCountdown(seconds) {
    clearInterval(this.countdownTimer)
    this.countdownTimer = setInterval(() => {
      seconds--
      const m = Math.floor(seconds / 60)
      const s = seconds % 60
      this.countdownTarget.textContent = `${m}:${s.toString().padStart(2, "0")}`
      if (seconds <= 0) {
        clearInterval(this.countdownTimer)
        this.countdownTarget.textContent = "Expirado"
      }
    }, 1000)
  }

  #showCodeError(msg) {
    this.codeErrorTarget.textContent = msg
    this.codeErrorTarget.classList.remove("hidden")
  }

  // ── Status pill ─────────────────────────────────────────────────────

  #setPill(label, kind, icon) {
    if (!this.hasStatusPillTarget) return
    const map = {
      success: ["--color-success", "--color-success-light"],
      warning: ["--color-warning", "--color-warning-light"],
      danger:  ["--color-danger",  "--color-danger-light"],
      muted:   ["--color-text-muted", "--color-surface-raised"]
    }
    const [fg, bg] = map[kind] || map.muted
    this.statusPillTarget.className =
      `inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-(${bg}) text-(${fg})`
    this.statusPillTarget.innerHTML = `<i class="ph ${icon}"></i> ${label}`
  }

  // ── Fetch helper ────────────────────────────────────────────────────

  #post(url, body) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify(body)
    })
  }
}
