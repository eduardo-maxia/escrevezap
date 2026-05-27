import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// States:  loading | qr | pairing-form | pairing-code | connected | failed
//
// Desktop default: QR tab active, QR auto-loaded when scan_qr_code status arrives
// Mobile default: Pairing tab auto-selected on small screens

export default class extends Controller {
  static targets = [
    "statusBadge", "statusDot", "statusText", "tabs",
    // QR
    "qrPanel", "qrTabBtn", "qrLoading", "qrImageWrapper", "qrImage",
    // Pairing
    "pairingPanel", "pairingTabBtn",
    "phoneFormWrapper", "phoneInput", "pairingSubmitBtn", "pairingBtnText",
    "pairingError", "pairingErrorText",
    "codeWrapper", "codeText",
    // Error / stopped
    "errorPanel", "errorTitle", "errorMessage",
    // Success
    "successPanel",
  ]

  static values = {
    qrUrl:             String,
    pairingUrl:        String,
    dashboardUrl:      String,
    status:            String,
    redirectOnSuccess: { type: Boolean, default: false },
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  connect() {
    this._qrRefreshTimer = null
    this._subscription   = null
    this._activeTab      = this._isMobile() ? "pairing" : "qr"

    this._subscribeToStatusChannel()

    // Only apply the tab UI if we're not already in a terminal/connected state
    const initialStatus = this.statusValue
    const skipTabs = ["working", "failed", "stopped"].includes(initialStatus)
    if (!skipTabs) this._applyInitialTab()

    this._handleStatus(initialStatus)
  }

  disconnect() {
    this._subscription?.unsubscribe()
    clearTimeout(this._qrRefreshTimer)
  }

  // ── ActionCable ─────────────────────────────────────────────────────────

  _subscribeToStatusChannel() {
    const self = this
    this._subscription = consumer.subscriptions.create("WahaSessionStatusChannel", {
      received(data) {
        self._handleStatus(data.status)
      }
    })
  }

  _handleStatus(status) {
    if (!status) return
    this.statusValue = status
    this._updateStatusBadge(status)

    switch (status) {
      case "working":
        this._showSuccess()
        break
      case "scan_qr_code":
        if (this._activeTab === "qr") this._loadQR()
        break
      case "starting":
        this._setStatusBadge("loading", "Iniciando sessão...")
        break
      case "failed":
        this._showErrorPanel(
          "Falha na conexão",
          "Ocorreu um erro ao tentar conectar. Reinicie a sessão para tentar novamente."
        )
        break
      case "stopped":
        this._showErrorPanel(
          "Sessão encerrada",
          "A sessão foi encerrada. Reinicie para reconectar seu WhatsApp."
        )
        break
    }
  }

  // ── Tab switching ───────────────────────────────────────────────────────

  showQRTab(event) {
    event?.preventDefault()
    this._activeTab = "qr"
    this._applyActiveTab()
    if (["scan_qr_code", "starting"].includes(this.statusValue)) {
      this._loadQR()
    }
  }

  showPairingTab(event) {
    event?.preventDefault()
    this._activeTab = "pairing"
    this._applyActiveTab()
  }

  _applyInitialTab() {
    this._applyActiveTab()
    // Auto-select pairing on mobile
    if (this._isMobile() && this.hasPairingTabBtnTarget) {
      this._activeTab = "pairing"
      this._applyActiveTab()
    }
  }

  _applyActiveTab() {
    const showQR      = this._activeTab === "qr"
    const activeBtn   = "bg-(--color-surface) shadow-sm text-(--color-text)"
    const inactiveBtn = "text-(--color-text-muted)"

    if (this.hasQrPanelTarget)      this.qrPanelTarget.classList.toggle("hidden", !showQR)
    if (this.hasPairingPanelTarget) this.pairingPanelTarget.classList.toggle("hidden", showQR)

    if (this.hasQrTabBtnTarget) {
      this.qrTabBtnTarget.className = this.qrTabBtnTarget.className
        .replace(showQR ? inactiveBtn : activeBtn, "")
        .trim()
      if (showQR) this.qrTabBtnTarget.classList.add(...activeBtn.split(" "))
      else        this.qrTabBtnTarget.classList.add(...inactiveBtn.split(" "))
    }
    if (this.hasPairingTabBtnTarget) {
      this.pairingTabBtnTarget.className = this.pairingTabBtnTarget.className
        .replace(!showQR ? inactiveBtn : activeBtn, "")
        .trim()
      if (!showQR) this.pairingTabBtnTarget.classList.add(...activeBtn.split(" "))
      else         this.pairingTabBtnTarget.classList.add(...inactiveBtn.split(" "))
    }
  }

  // ── QR Code ─────────────────────────────────────────────────────────────

  refreshQR(event) {
    event?.preventDefault()
    this._loadQR()
  }

  _loadQR() {
    clearTimeout(this._qrRefreshTimer)
    this._showQRLoading()

    fetch(this.qrUrlValue, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => {
        if (data.qr) {
          this._showQRImage(data.qr)
          // Auto-refresh before QR expires (~25 s)
          this._qrRefreshTimer = setTimeout(() => this._loadQR(), 25_000)
        } else {
          // QR not ready yet — Waha still starting, retry
          this._qrRefreshTimer = setTimeout(() => this._loadQR(), 2_500)
        }
      })
      .catch(() => {
        this._qrRefreshTimer = setTimeout(() => this._loadQR(), 3_000)
      })
  }

  _showQRLoading() {
    if (this.hasQrLoadingTarget)      this.qrLoadingTarget.classList.remove("hidden")
    if (this.hasQrImageWrapperTarget) this.qrImageWrapperTarget.classList.add("hidden")
  }

  _showQRImage(src) {
    if (this.hasQrImageTarget)       this.qrImageTarget.src = src
    if (this.hasQrLoadingTarget)     this.qrLoadingTarget.classList.add("hidden")
    if (this.hasQrImageWrapperTarget) this.qrImageWrapperTarget.classList.remove("hidden")
  }

  // ── Pairing code ─────────────────────────────────────────────────────────

  requestPairingCode(event) {
    event.preventDefault()
    const phone = this.hasPhoneInputTarget ? this.phoneInput.value.trim() : ""

    if (!phone) {
      this._showPairingError("Digite seu número de telefone")
      return
    }

    this._setPairingBtnLoading(true)
    this._hidePairingError()

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.pairingUrlValue, {
      method:  "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrf,
        Accept:          "application/json",
      },
      body: `phone_number=${encodeURIComponent(phone)}`,
    })
      .then(r => r.json())
      .then(data => {
        this._setPairingBtnLoading(false)
        if (data.code) {
          this._showPairingCode(data.code)
        } else {
          this._showPairingError(data.error || "Não foi possível gerar o código")
        }
      })
      .catch(() => {
        this._setPairingBtnLoading(false)
        this._showPairingError("Erro de conexão — tente novamente")
      })
  }

  resetPairing(event) {
    event?.preventDefault()
    if (this.hasCodeWrapperTarget)      this.codeWrapperTarget.classList.add("hidden")
    if (this.hasPhoneFormWrapperTarget) this.phoneFormWrapperTarget.classList.remove("hidden")
    this._hidePairingError()
  }

  _showPairingCode(code) {
    if (this.hasCodeTextTarget)         this.codeTextTarget.textContent = code
    if (this.hasPhoneFormWrapperTarget) this.phoneFormWrapperTarget.classList.add("hidden")
    if (this.hasCodeWrapperTarget)      this.codeWrapperTarget.classList.remove("hidden")
  }

  _setPairingBtnLoading(loading) {
    if (!this.hasPairingSubmitBtnTarget) return
    this.pairingSubmitBtnTarget.disabled = loading
    if (this.hasPairingBtnTextTarget)
      this.pairingBtnTextTarget.textContent = loading ? "Gerando código..." : "Receber código"
  }

  _showPairingError(msg) {
    if (this.hasPairingErrorTarget)     this.pairingErrorTarget.classList.remove("hidden")
    if (this.hasPairingErrorTextTarget) this.pairingErrorTextTarget.textContent = msg
  }

  _hidePairingError() {
    if (this.hasPairingErrorTarget) this.pairingErrorTarget.classList.add("hidden")
  }

  // ── Error / stopped ──────────────────────────────────────────────────────

  _showErrorPanel(title, message) {
    clearTimeout(this._qrRefreshTimer)
    if (this.hasQrPanelTarget)      this.qrPanelTarget.classList.add("hidden")
    if (this.hasPairingPanelTarget) this.pairingPanelTarget.classList.add("hidden")
    if (this.hasTabsTarget)         this.tabsTarget.classList.add("hidden")
    if (this.hasSuccessPanelTarget) this.successPanelTarget.classList.add("hidden")
    if (this.hasErrorTitleTarget)   this.errorTitleTarget.textContent = title
    if (this.hasErrorMessageTarget) this.errorMessageTarget.textContent = message
    if (this.hasErrorPanelTarget)   this.errorPanelTarget.classList.remove("hidden")
  }

  // ── Success ──────────────────────────────────────────────────────────────

  _showSuccess() {
    clearTimeout(this._qrRefreshTimer)
    if (this.hasQrPanelTarget)      this.qrPanelTarget.classList.add("hidden")
    if (this.hasPairingPanelTarget) this.pairingPanelTarget.classList.add("hidden")
    if (this.hasTabsTarget)         this.tabsTarget.classList.add("hidden")
    if (this.hasSuccessPanelTarget) this.successPanelTarget.classList.remove("hidden")

    this._setStatusBadge("connected", "Conectado!")

    setTimeout(() => {
      if (this.redirectOnSuccessValue && this.dashboardUrlValue) {
        window.location.href = this.dashboardUrlValue
      }
    }, 1_800)
  }

  // ── Status badge helpers ─────────────────────────────────────────────────

  _updateStatusBadge(status) {
    const map = {
      pending:      ["bg-gray-400", "Aguardando..."],
      starting:     ["bg-yellow-400 animate-pulse", "Iniciando sessão..."],
      scan_qr_code: ["bg-blue-400 animate-pulse", "Aguardando QR Code..."],
      working:      ["bg-(--color-success)", "Conectado!"],
      failed:       ["bg-(--color-danger)", "Falha na conexão"],
      stopped:      ["bg-gray-400", "Sessão encerrada"],
    }
    const [dotClass, text] = map[status] || ["bg-gray-300", status]
    this._setStatusBadge(null, text, dotClass)
  }

  _setStatusBadge(state, text, dotClass) {
    if (this.hasStatusTextTarget) this.statusTextTarget.textContent = text
    if (this.hasStatusDotTarget && dotClass) {
      this.statusDotTarget.className = `w-2 h-2 rounded-full ${dotClass}`
    }
  }

  // ── Utilities ────────────────────────────────────────────────────────────

  get phoneInput() {
    return this.hasPhoneInputTarget ? this.phoneInputTarget : null
  }

  _isMobile() {
    return window.innerWidth < 768
  }
}
