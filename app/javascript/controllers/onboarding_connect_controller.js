import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"
import intlTelInput from "intl-tel-input/intlTelInputWithUtils"

export default class extends Controller {
  static targets = [
    "statusBadge", "statusDot", "statusText",
    "pairingPanel", "phoneFormWrapper", "phoneInput", "pairingSubmitBtn", "pairingBtnText",
    "pairingError", "pairingErrorText", "codeWrapper", "codeText",
    "errorPanel", "errorTitle", "errorMessage", "reconnectButton", "reconnectButtonText",
    "successPanel"
  ]

  static values = {
    pairingUrl: String,
    reconnectUrl: String,
    dashboardUrl: String,
    statusUrl: String,
    status: String
  }

  connect() {
    this.redirectTimer = null
    this.subscription = null
    this.pollTimer = null

    this.subscribeToStatusChannel()
    this.startPolling()
    this.initIntlTelInput()
    this.handleStatus(this.statusValue)
  }

  disconnect() {
    this.subscription?.unsubscribe()
    clearTimeout(this.redirectTimer)
    clearTimeout(this.pollTimer)
    this.iti?.destroy()
  }

  initIntlTelInput() {
    if (!this.hasPhoneInputTarget) return

    this.iti = intlTelInput(this.phoneInputTarget, {
      initialCountry: "br",
      preferredCountries: ["br", "us", "pt"],
      showSelectedDialCode: true
    })
  }

  requestPairingCode(event) {
    event.preventDefault()

    const phone = this.iti ? this.iti.getNumber() : (this.hasPhoneInputTarget ? this.phoneInputTarget.value.trim() : "")

    if (!phone) {
      this.showPairingError("Digite seu número com DDI e DDD.")
      return
    }

    if (this.iti && !this.iti.isValidNumber()) {
      this.showPairingError("Número de telefone inválido.")
      return
    }

    // Clean formatting before sending
    const cleanPhone = phone.replace(/\D/g, "")

    this.hidePairingError()
    this.setPairingButtonLoading(true)

    fetch(this.pairingUrlValue, {
      method: "POST",
      headers: this.requestHeaders("application/x-www-form-urlencoded"),
      body: `phone_number=${encodeURIComponent(cleanPhone)}`
    })
      .then(async (response) => {
        const data = await response.json()

        if (!response.ok) {
          throw new Error(data.error || "Não foi possível gerar o código.")
        }

        if (!data.code) {
          throw new Error("Código indisponível. Tente novamente.")
        }

        this.showPairingCode(data.code)
      })
      .catch((error) => {
        this.showPairingError(error.message)
      })
      .finally(() => {
        this.setPairingButtonLoading(false)
      })
  }

  resetPairing(event) {
    event.preventDefault()
    this.codeWrapperTarget.classList.add("hidden")
    this.codeWrapperTarget.classList.remove("flex")
    this.phoneFormWrapperTarget.classList.remove("hidden")
    this.hidePairingError()
  }

  reconnect(event) {
    event.preventDefault()
    this.setReconnectButtonLoading(true)

    fetch(this.reconnectUrlValue, {
      method: "POST",
      headers: this.requestHeaders()
    })
      .then(async (response) => {
        const data = await response.json()

        if (!response.ok) {
          throw new Error(data.error || "Falha ao reiniciar sessão.")
        }

        this.handleStatus(data.status || "starting")
      })
      .catch((error) => {
        this.showError("Falha ao reiniciar", error.message)
      })
      .finally(() => {
        this.setReconnectButtonLoading(false)
      })
  }

  subscribeToStatusChannel() {
    this.subscription = consumer.subscriptions.create("WahaSessionStatusChannel", {
      received: (data) => {
        this.handleStatus(data.status)
      }
    })
  }

  startPolling() {
    if (!this.statusUrlValue) return

    const poll = () => {
      fetch(this.statusUrlValue, { headers: this.requestHeaders() })
        .then(r => r.json())
        .then(data => {
          if (data.status && data.status !== this.statusValue) {
            this.handleStatus(data.status)
          }
        })
        .finally(() => {
          // Poll every 3 seconds
          if (this.statusValue !== "working" && this.statusValue !== "failed" && this.statusValue !== "stopped") {
            this.pollTimer = setTimeout(poll, 3000)
          }
        })
    }

    this.pollTimer = setTimeout(poll, 3000)
  }

  handleStatus(status) {
    if (!status) return

    this.statusValue = status
    this.updateStatusBadge(status)

    if (status === "working") {
      this.showSuccess()
      return
    }

    if (status === "failed") {
      this.showError("Falha na conexão", "Não foi possível conectar seu WhatsApp. Reinicie para tentar novamente.")
      return
    }

    if (status === "stopped") {
      this.showError("Sessão desconectada", "A sessão foi encerrada no WhatsApp. Reinicie para reconectar.")
      return
    }

    this.hideTerminalStates()
  }

  showPairingCode(code) {
    this.codeTextTarget.textContent = code
    this.phoneFormWrapperTarget.classList.add("hidden")
    this.codeWrapperTarget.classList.remove("hidden")
    this.codeWrapperTarget.classList.add("flex")
  }

  setPairingButtonLoading(loading) {
    this.pairingSubmitBtnTarget.disabled = loading
    this.pairingBtnTextTarget.textContent = loading ? "Gerando código..." : "Receber código"
  }

  setReconnectButtonLoading(loading) {
    this.reconnectButtonTarget.disabled = loading

    if (loading) {
      this.reconnectButtonTextTarget.innerHTML = '<span class="btn-spinner" aria-hidden="true"></span>Reiniciando...'
      return
    }

    this.reconnectButtonTextTarget.textContent = "Reiniciar sessão"
  }

  showPairingError(message) {
    this.pairingErrorTextTarget.textContent = message
    this.pairingErrorTarget.classList.remove("hidden")
    this.pairingErrorTarget.classList.add("flex")
  }

  hidePairingError() {
    this.pairingErrorTarget.classList.add("hidden")
    this.pairingErrorTarget.classList.remove("flex")
  }

  showError(title, message) {
    clearTimeout(this.pollTimer)

    this.errorTitleTarget.textContent = title
    this.errorMessageTarget.textContent = message

    this.pairingPanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.remove("flex")
    this.errorPanelTarget.classList.remove("hidden")
    this.errorPanelTarget.classList.add("flex")
  }

  showSuccess() {
    clearTimeout(this.pollTimer)

    this.pairingPanelTarget.classList.add("hidden")
    this.errorPanelTarget.classList.add("hidden")
    this.errorPanelTarget.classList.remove("flex")
    this.successPanelTarget.classList.remove("hidden")
    this.successPanelTarget.classList.add("flex")

    this.updateStatusBadge("working")

    this.redirectTimer = setTimeout(() => {
      if (this.dashboardUrlValue) {
        window.location.href = this.dashboardUrlValue
      }
    }, 1600)
  }

  hideTerminalStates() {
    this.errorPanelTarget.classList.add("hidden")
    this.errorPanelTarget.classList.remove("flex")
    this.successPanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.remove("flex")
    this.pairingPanelTarget.classList.remove("hidden")
  }

  updateStatusBadge(status) {
    const map = {
      pending: ["bg-gray-400", "Aguardando inicialização..."],
      starting: ["bg-yellow-400 animate-pulse", "Iniciando sessão..."],
      scan_qr_code: ["bg-blue-500 animate-pulse", "Aguardando conexão..."],
      working: ["bg-(--color-success)", "Conectado com sucesso"],
      failed: ["bg-(--color-danger)", "Falha na conexão"],
      stopped: ["bg-gray-400", "Sessão desconectada"]
    }

    const [dotClass, text] = map[status] || ["bg-gray-400", "Atualizando status..."]
    if (this.hasStatusTextTarget) this.statusTextTarget.textContent = text
    if (this.hasStatusDotTarget) this.statusDotTarget.className = `h-2 w-2 rounded-full ${dotClass}`
  }

  requestHeaders(contentType = null) {
    const headers = {
      Accept: "application/json"
    }

    if (contentType) {
      headers["Content-Type"] = contentType
    }

    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrf) {
      headers["X-CSRF-Token"] = csrf
    }

    return headers
  }
}
