import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dropzone", "input", "loading", "result", "error", "errorText", "summaryBlock", "summaryText", "formattedText" ]
  static values = { url: String }

  connect() {
    this.reset()
  }

  browse() {
    this.inputTarget.click()
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("bg-gray-50", "border-(--color-brand)")
  }

  dragleave(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("bg-gray-50", "border-(--color-brand)")
  }

  drop(event) {
    event.preventDefault()
    this.dragleave(event)
    
    if (event.dataTransfer.files && event.dataTransfer.files.length > 0) {
      this.inputTarget.files = event.dataTransfer.files
      this.upload()
    }
  }

  upload() {
    const file = this.inputTarget.files[0]
    if (!file) return

    // Simple validation
    if (!file.type.startsWith("audio/")) {
      this.showError("Por favor, selecione um arquivo de áudio válido.")
      return
    }

    if (file.size > 1 * 1024 * 1024) { // 1MB limit for demo
      this.showError("Arquivo muito grande. O tamanho máximo é 1MB.")
      return
    }

    this.dropzoneTarget.classList.add("hidden")
    this.errorTarget.classList.add("hidden")
    this.loadingTarget.classList.remove("hidden")
    
    const formData = new FormData()
    formData.append("audio", file)

    // Append CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    
    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: formData
    })
    .then(response => {
      if (!response.ok) {
        return response.json().then(err => { throw new Error(err.error || "Erro ao processar o áudio.") })
      }
      return response.json()
    })
    .then(data => {
      this.showResult(data)
    })
    .catch(error => {
      this.showError(error.message)
    })
  }

  showResult(data) {
    this.loadingTarget.classList.add("hidden")
    this.resultTarget.classList.remove("hidden")

    if (data.summary) {
      this.summaryBlockTarget.classList.remove("hidden")
      this.summaryTextTarget.textContent = data.summary
    } else {
      this.summaryBlockTarget.classList.add("hidden")
    }

    this.formattedTextTarget.textContent = data.full_formatted || data.transcript
  }

  showError(message) {
    this.loadingTarget.classList.add("hidden")
    this.dropzoneTarget.classList.add("hidden")
    this.resultTarget.classList.add("hidden")
    
    this.errorTarget.classList.remove("hidden")
    this.errorTextTarget.textContent = message
  }

  reset() {
    this.inputTarget.value = ""
    this.dropzoneTarget.classList.remove("hidden")
    this.loadingTarget.classList.add("hidden")
    this.resultTarget.classList.add("hidden")
    this.errorTarget.classList.add("hidden")
  }
}
