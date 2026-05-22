import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = [
    "statusBadge", "statusText",
    "qrTab", "codeTab",
    "qrPanel", "codePanel", "successPanel", "errorPanel",
    "qrSpinner", "qrImage", "qrHint",
    "phoneForm", "phoneInput", "requestCodeBtn", "codeError",
    "codeDisplay", "codeBoxes", "countdown", "copyBtn",
    "errorMessage", "skipLink"
  ]

  static values = {
    startUrl:       String,
    requestCodeUrl: String,
    qrUrl:          String,
    statusUrl:      String,
    step4Url:       String
  }

  connect() {
    this.cable = createConsumer()
    this.subscription = null
    this.countdownTimer = null
    this.pollTimer = null
    this.#resolved = false
    this.startSession()
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.cable?.disconnect()
    clearInterval(this.countdownTimer)
    clearInterval(this.pollTimer)
  }

  // ── Session lifecycle ─────────────────────────────────────────────────

  async startSession() {
    try {
      const resp = await this.#post(this.startUrlValue, {})
      const data = await resp.json()
      if (!resp.ok) throw new Error(data.error || "Erro ao iniciar sessão.")
      this.#subscribeToChip(data.chip_id)
      this.#startPolling()
      if (data.status) this.#handleStatus({ status: data.status })
    } catch (err) {
      this.#showErrorPanel(err.message)
    }
  }

  async retrySession() {
    this.errorPanelTarget.classList.add("hidden")
    this.qrPanelTarget.classList.remove("hidden")
    this.qrSpinnerTarget.classList.remove("hidden")
    this.qrImageTarget.classList.add("hidden")
    this.#setStatus("Reiniciando sessão...", "warning")
    this.subscription?.unsubscribe()
    this.subscription = null
    await this.startSession()
  }

  // ── ActionCable ───────────────────────────────────────────────────────

  #subscribeToChip(chipId) {
    this.subscription = this.cable.subscriptions.create(
      { channel: "ChipStatusChannel", chip_id: chipId },
      {
        received: (data) => this.#handleStatus(data),
        rejected: () => this.#showErrorPanel("Não foi possível conectar ao canal de status.")
      }
    )
  }

  // ── Polling fallback ──────────────────────────────────────────────────

  #startPolling() {
    if (!this.statusUrlValue) return
    this.pollTimer = setInterval(async () => {
      if (this.#resolved) { clearInterval(this.pollTimer); return }
      try {
        const resp = await fetch(this.statusUrlValue, { headers: { "Accept": "application/json" } })
        if (!resp.ok) return
        const data = await resp.json()
        this.#handleStatus(data)
      } catch { /* network hiccup — try again next tick */ }
    }, 3000)
  }

  #handleStatus({ status }) {
    console.log("Chip status update:", status)
    switch (status?.toLowerCase()) {
      case "starting":
        this.#setStatus("Iniciando sessão...", "warning")
        break
      case "scan_qr_code":
        this.#setStatus("Aguardando leitura do QR code", "warning")
        this.#fetchQr()
        break
      case "working":
        if (this.#resolved) return
        this.#resolved = true
        clearInterval(this.pollTimer)
        this.#setStatus("Conectado!", "success")
        this.#showSuccess()
        setTimeout(() => { window.location.href = this.step4UrlValue }, 1500)
        break
      case "failed":
        if (this.#resolved) return
        this.#resolved = true
        clearInterval(this.pollTimer)
        this.#setStatus("Falha na conexão", "error")
        this.#showErrorPanel("A sessão falhou. Tente reiniciar ou entre em contato com o suporte.")
        break
      case "stopped":
        this.#setStatus("Sessão parada", "warning")
        break
    }
  }

  // ── QR code ───────────────────────────────────────────────────────────

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

  // ── Pairing code ──────────────────────────────────────────────────────

  async requestCode() {
    const phone = this.phoneInputTarget.value.replace(/\D/g, "")
    if (!phone) {
      this.#showCodeError("Informe seu número de WhatsApp.")
      return
    }

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

  // ── Tab switching ─────────────────────────────────────────────────────

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

  // ── Private helpers ───────────────────────────────────────────────────

  #post(url, body) {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    return fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-CSRF-Token": token },
      body: JSON.stringify(body)
    })
  }

  #showCode(code) {
    // code arrives as "ABCD-EFGH" — render one box per character, dash as separator
    this._currentCode = code
    const chars = code.replace(/-/g, "").split("")  // ["A","B","C","D","E","F","G","H"]

    const boxCls = [
      "w-10 h-12 rounded-xl border-2 border-(--color-brand)",
      "bg-(--color-brand-subtle) flex items-center justify-center",
      "font-bold text-xl text-(--color-brand) select-all"
    ].join(" ")

    const sep = `<div class="flex items-center px-1 text-lg font-semibold text-(--color-text-subtle) select-none">–</div>`

    const boxes = chars.map(c => `<div class="${boxCls}">${c}</div>`)
    boxes.splice(4, 0, sep)   // insert dash after 4th char

    this.codeBoxesTarget.innerHTML = boxes.join("")

    this.phoneFormTarget.classList.add("hidden")
    this.codeDisplayTarget.classList.remove("hidden")
    this.#startCountdown(5 * 60)
  }

  async copyCode() {
    if (!this._currentCode) return
    try {
      await navigator.clipboard.writeText(this._currentCode)
      if (this.hasCopyBtnTarget) {
        const btn = this.copyBtnTarget
        const original = btn.innerHTML
        btn.innerHTML = '<i class="ph ph-check text-sm"></i> Copiado!'
        btn.disabled = true
        setTimeout(() => { btn.innerHTML = original; btn.disabled = false }, 2000)
      }
    } catch { /* clipboard unavailable */ }
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

  #showSuccess() {
    this.qrPanelTarget.classList.add("hidden")
    this.codePanelTarget.classList.add("hidden")
    this.errorPanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.remove("hidden")
    if (this.hasSkipLinkTarget) this.skipLinkTarget.classList.add("hidden")
  }

  #showErrorPanel(message) {
    this.qrPanelTarget.classList.add("hidden")
    this.codePanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.add("hidden")
    this.errorPanelTarget.classList.remove("hidden")
    this.errorMessageTarget.textContent = message
  }

  #showCodeError(message) {
    this.codeErrorTarget.textContent = message
    this.codeErrorTarget.classList.remove("hidden")
  }

  #setStatus(text, type) {
    // this.statusTextTarget.textContent = text
    // const dot = this.statusBadgeTarget.querySelector("div")
    // dot.className = [
    //   "w-2 h-2 rounded-full",
    //   type === "success" ? "bg-(--color-success)" :
    //   type === "error"   ? "bg-(--color-error)" :
    //                        "bg-(--color-warning) animate-pulse"
    // ].join(" ")
  }
}
