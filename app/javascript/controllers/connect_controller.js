import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"
import intlTelInput from "intl-tel-input/intlTelInputWithUtils"

export default class extends Controller {
  static targets = [
    "statusBadge", "statusDot", "statusText",
    "pairingPanel",
    "phoneFormWrapper", "phoneInput", "pairingSubmitBtn", "pairingBtnText",
    "pairingError", "pairingErrorText",
    "codeWrapper", "codeText",
    "errorPanel", "errorTitle", "errorMessage", "reconnectButton", "reconnectButtonText",
    "successPanel",
  ]

  static values = {
    pairingUrl:        String,
    reconnectUrl:      String,
    dashboardUrl:      String,
    statusUrl:         String,
    status:            String,
    redirectOnSuccess: { type: Boolean, default: false },
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  connect() {
    this._subscription   = null
    this._pollTimer      = null

    this._subscribeToStatusChannel()
    this._startPolling()
    this._initIntlTelInput()

    this._handleStatus(this.statusValue)
  }

  disconnect() {
    this._subscription?.unsubscribe()
    clearTimeout(this._pollTimer)
    this._iti?.destroy()
  }

  _initIntlTelInput() {
    if (!this.hasPhoneInputTarget) return

    this._iti = intlTelInput(this.phoneInputTarget, {
      initialCountry: "br",
      preferredCountries: ["br", "us", "pt"],
      showSelectedDialCode: true
    })
  }

  // ── ActionCable & Polling ─────────────────────────────────────────────────────────

  _subscribeToStatusChannel() {
    const self = this
    this._subscription = consumer.subscriptions.create("WahaSessionStatusChannel", {
      received(data) {
        self._handleStatus(data.status)
      }
    })
  }

  _startPolling() {
    if (!this.statusUrlValue) return

    const poll = () => {
      fetch(this.statusUrlValue, { headers: this._requestHeaders() })
        .then(r => r.json())
        .then(data => {
          if (data.status && data.status !== this.statusValue) {
            this._handleStatus(data.status)
          }
        })
        .finally(() => {
          if (this.statusValue !== "working" && this.statusValue !== "failed" && this.statusValue !== "stopped") {
            this._pollTimer = setTimeout(poll, 3000)
          }
        })
    }

    this._pollTimer = setTimeout(poll, 3000)
  }

  _handleStatus(status) {
    if (!status) return
    this.statusValue = status
    this._updateStatusBadge(status)

    switch (status) {
      case "working":
        this._showSuccess()
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
      default:
        this._hideTerminalStates()
        break
    }
  }

  // ── Pairing code ─────────────────────────────────────────────────────────

  requestPairingCode(event) {
    event.preventDefault()
    const phone = this._iti ? this._iti.getNumber() : (this.hasPhoneInputTarget ? this.phoneInput.value.trim() : "")

    if (!phone) {
      this._showPairingError("Digite seu número de telefone")
      return
    }

    if (this._iti && !this._iti.isValidNumber()) {
      this._showPairingError("Número de telefone inválido")
      return
    }

    // Clean formatting before sending
    const cleanPhone = phone.replace(/\D/g, "")

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
      body: `phone_number=${encodeURIComponent(cleanPhone)}`,
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
    if (this.hasCodeWrapperTarget)      this.codeWrapperTarget.classList.add("flex")
  }

  reconnect(event) {
    event?.preventDefault()

    if (!this.reconnectUrlValue) return

    this._setReconnectButtonLoading(true)

    fetch(this.reconnectUrlValue, {
      method: "POST",
      headers: this._requestHeaders(),
    })
      .then(async (response) => {
        const data = await response.json()

        if (!response.ok) {
          throw new Error(data.error || "Falha ao reiniciar sessão")
        }

        this._hideTerminalStates()
        this._handleStatus(data.status || "starting")
      })
      .catch((error) => {
        this._showErrorPanel("Falha ao reiniciar", error.message)
      })
      .finally(() => {
        this._setReconnectButtonLoading(false)
      })
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
    clearTimeout(this._pollTimer)
    if (this.hasPairingPanelTarget) this.pairingPanelTarget.classList.add("hidden")
    if (this.hasSuccessPanelTarget) this.successPanelTarget.classList.add("hidden")
    if (this.hasErrorTitleTarget)   this.errorTitleTarget.textContent = title
    if (this.hasErrorMessageTarget) this.errorMessageTarget.textContent = message
    if (this.hasErrorPanelTarget)   this.errorPanelTarget.classList.remove("hidden")
  }

  _hideTerminalStates() {
    if (this.hasErrorPanelTarget) this.errorPanelTarget.classList.add("hidden")
    if (this.hasPairingPanelTarget) this.pairingPanelTarget.classList.remove("hidden")
  }

  // ── Success ──────────────────────────────────────────────────────────────

  _showSuccess() {
    clearTimeout(this._pollTimer)
    if (this.hasPairingPanelTarget) this.pairingPanelTarget.classList.add("hidden")
    if (this.hasSuccessPanelTarget) this.successPanelTarget.classList.remove("hidden")

    this._setStatusBadge("connected", "Conectado!")

    setTimeout(() => {
      if (this.redirectOnSuccessValue && this.dashboardUrlValue) {
        window.location.href = this.dashboardUrlValue
      }
    }, 1_800)
  }

  _setReconnectButtonLoading(loading) {
    if (!this.hasReconnectButtonTarget) return

    this.reconnectButtonTarget.disabled = loading

    if (!this.hasReconnectButtonTextTarget) return

    this.reconnectButtonTextTarget.textContent = loading ? "Reiniciando..." : "Reiniciar sessão"
  }

  // ── Status badge helpers ─────────────────────────────────────────────────

  _updateStatusBadge(status) {
    const map = {
      pending:      ["bg-gray-400", "Aguardando..."],
      starting:     ["bg-yellow-400 animate-pulse", "Iniciando sessão..."],
      scan_qr_code: ["bg-blue-400 animate-pulse", "Aguardando conexão..."],
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

  _requestHeaders(contentType = null) {
    const headers = { Accept: "application/json" }
    if (contentType) headers["Content-Type"] = contentType

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) headers["X-CSRF-Token"] = csrf

    return headers
  }

  // ── Utilities ────────────────────────────────────────────────────────────

  get phoneInput() {
    return this.hasPhoneInputTarget ? this.phoneInputTarget : null
  }
}
