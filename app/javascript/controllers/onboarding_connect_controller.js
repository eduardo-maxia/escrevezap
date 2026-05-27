import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = [
    "tabs", "qrTabBtn", "pairingTabBtn",
    "statusBadge", "statusDot", "statusText",
    "qrPanel", "qrLoading", "qrImageWrapper", "qrImage",
    "pairingPanel", "phoneFormWrapper", "phoneInput", "pairingSubmitBtn", "pairingBtnText",
    "pairingError", "pairingErrorText", "codeWrapper", "codeText",
    "errorPanel", "errorTitle", "errorMessage", "reconnectButton", "reconnectButtonText",
    "successPanel"
  ]

  static values = {
    qrUrl: String,
    pairingUrl: String,
    reconnectUrl: String,
    dashboardUrl: String,
    status: String
  }

  connect() {
    this.activeTab = window.innerWidth < 768 ? "pairing" : "qr"
    this.qrTimer = null
    this.redirectTimer = null
    this.subscription = null

    this.applyTabState()
    this.subscribeToStatusChannel()
    this.handleStatus(this.statusValue)
  }

  disconnect() {
    this.subscription?.unsubscribe()
    clearTimeout(this.qrTimer)
    clearTimeout(this.redirectTimer)
  }

  showQRTab(event) {
    event.preventDefault()
    this.activeTab = "qr"
    this.applyTabState()
    if (["starting", "scan_qr_code"].includes(this.statusValue)) {
      this.loadQr()
    }
  }

  showPairingTab(event) {
    event.preventDefault()
    this.activeTab = "pairing"
    this.applyTabState()
  }

  refreshQR(event) {
    event?.preventDefault()
    this.loadQr(true)
  }

  requestPairingCode(event) {
    event.preventDefault()

    const phone = this.hasPhoneInputTarget ? this.phoneInputTarget.value.trim() : ""
    if (!phone) {
      this.showPairingError("Digite seu número com DDI e DDD.")
      return
    }

    this.hidePairingError()
    this.setPairingButtonLoading(true)

    fetch(this.pairingUrlValue, {
      method: "POST",
      headers: this.requestHeaders("application/x-www-form-urlencoded"),
      body: `phone_number=${encodeURIComponent(phone)}`
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
      connected: () => {
        if (["starting", "scan_qr_code"].includes(this.statusValue) && this.activeTab === "qr") {
          this.loadQr()
        }
      },
      received: (data) => {
        this.handleStatus(data.status)
      }
    })
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

    if (status === "starting" || status === "scan_qr_code") {
      if (this.activeTab === "qr") {
        this.loadQr()
      }
    }
  }

  applyTabState() {
    const qrActive = this.activeTab === "qr"

    this.qrPanelTarget.classList.toggle("hidden", !qrActive)
    this.pairingPanelTarget.classList.toggle("hidden", qrActive)

    this.qrTabBtnTarget.classList.toggle("bg-(--color-surface)", qrActive)
    this.qrTabBtnTarget.classList.toggle("shadow-sm", qrActive)
    this.qrTabBtnTarget.classList.toggle("text-(--color-text)", qrActive)
    this.qrTabBtnTarget.classList.toggle("text-(--color-text-muted)", !qrActive)

    this.pairingTabBtnTarget.classList.toggle("bg-(--color-surface)", !qrActive)
    this.pairingTabBtnTarget.classList.toggle("shadow-sm", !qrActive)
    this.pairingTabBtnTarget.classList.toggle("text-(--color-text)", !qrActive)
    this.pairingTabBtnTarget.classList.toggle("text-(--color-text-muted)", qrActive)
  }

  loadQr(force = false) {
    clearTimeout(this.qrTimer)
    this.showQrLoading()

    fetch(this.qrUrlValue, { headers: this.requestHeaders() })
      .then(async (response) => {
        const data = await response.json()

        if (!response.ok) {
          throw new Error(data.error || "QR indisponível")
        }

        if (data.qr) {
          this.showQrImage(data.qr)
          this.qrTimer = setTimeout(() => this.loadQr(), 25_000)
          return
        }

        this.qrTimer = setTimeout(() => this.loadQr(), force ? 2_000 : 3_000)
      })
      .catch(() => {
        this.qrTimer = setTimeout(() => this.loadQr(), 3_000)
      })
  }

  showQrLoading() {
    this.qrLoadingTarget.classList.remove("hidden")
    this.qrImageWrapperTarget.classList.add("hidden")
    this.qrImageWrapperTarget.classList.remove("flex")
  }

  showQrImage(src) {
    this.qrImageTarget.src = src
    this.qrLoadingTarget.classList.add("hidden")
    this.qrImageWrapperTarget.classList.remove("hidden")
    this.qrImageWrapperTarget.classList.add("flex")
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
    clearTimeout(this.qrTimer)

    this.errorTitleTarget.textContent = title
    this.errorMessageTarget.textContent = message

    this.tabsTarget.classList.add("hidden")
    this.qrPanelTarget.classList.add("hidden")
    this.pairingPanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.add("hidden")
    this.successPanelTarget.classList.remove("flex")
    this.errorPanelTarget.classList.remove("hidden")
    this.errorPanelTarget.classList.add("flex")
  }

  showSuccess() {
    clearTimeout(this.qrTimer)

    this.tabsTarget.classList.add("hidden")
    this.qrPanelTarget.classList.add("hidden")
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
    this.tabsTarget.classList.remove("hidden")

    if (this.activeTab === "qr") {
      this.qrPanelTarget.classList.remove("hidden")
      this.pairingPanelTarget.classList.add("hidden")
    } else {
      this.qrPanelTarget.classList.add("hidden")
      this.pairingPanelTarget.classList.remove("hidden")
    }
  }

  updateStatusBadge(status) {
    const map = {
      pending: ["bg-gray-400", "Aguardando inicialização..."],
      starting: ["bg-yellow-400 animate-pulse", "Iniciando sessão..."],
      scan_qr_code: ["bg-blue-500 animate-pulse", "Escaneie o QR Code para conectar"],
      working: ["bg-(--color-success)", "Conectado com sucesso"],
      failed: ["bg-(--color-danger)", "Falha na conexão"],
      stopped: ["bg-gray-400", "Sessão desconectada"]
    }

    const [dotClass, text] = map[status] || ["bg-gray-400", "Atualizando status..."]
    this.statusTextTarget.textContent = text
    this.statusDotTarget.className = `h-2 w-2 rounded-full ${dotClass}`
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
