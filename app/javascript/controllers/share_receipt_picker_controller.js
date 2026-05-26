import { Controller } from "@hotwired/stimulus"

const SHARED_CACHE = "shared-receipts"

export default class extends Controller {
  static targets = ["fileStatus"]

  async connect() {
    this.token = new URLSearchParams(window.location.search).get("token")

    if (!this.token) {
      this.#showStatus("Nenhum arquivo compartilhado foi encontrado. Compartilhe novamente o comprovante para continuar.", false)
      return
    }

    try {
      const cache = await caches.open(SHARED_CACHE)
      const response = await cache.match(`/__shared/${this.token}`)

      if (!response) {
        this.#showStatus("O comprovante não foi encontrado. Compartilhe novamente para continuar.", false)
        return
      }

      this.fileBlob = await response.blob()
      const rawName = response.headers.get("X-Filename") || "comprovante"
      this.fileName = decodeURIComponent(rawName)

      this.#showStatus(`Arquivo recebido: ${this.fileName}`, true)
    } catch {
      this.#showStatus("Não foi possível acessar o arquivo compartilhado no momento.", false)
    }
  }

  async attach(event) {
    const installmentId = event.params.installmentId
    const markPaid = event.params.markPaid === true || event.params.markPaid === "true"

    if (!this.fileBlob || !installmentId) {
      this.#showStatus("Arquivo indisponível. Compartilhe novamente o comprovante.", false)
      return
    }

    const button = event.currentTarget
    const originalHtml = button.innerHTML
    button.disabled = true
    button.innerHTML = `<span class="btn-spinner"></span><span>Salvando...</span>`

    try {
      const formData = new FormData()
      formData.append("installment_id", installmentId)
      formData.append("receipt", new File([this.fileBlob], this.fileName, { type: this.fileBlob.type || "application/octet-stream" }))
      if (markPaid) formData.append("mark_paid", "true")

      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
      const response = await fetch("/app/share-receipt/attach", {
        method: "POST",
        headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
        body: formData,
      })

      if (!response.ok) {
        const payload = await response.json().catch(() => ({}))
        const msg = payload?.errors?.join(", ") || "Não foi possível salvar o comprovante."
        throw new Error(msg)
      }

      const cache = await caches.open(SHARED_CACHE)
      await cache.delete(`/__shared/${this.token}`)
      window.location.href = "/app?notice=Comprovante+vinculado+com+sucesso"
    } catch (error) {
      this.#showStatus(error.message || "Falha ao salvar comprovante.", false)
      button.disabled = false
      button.innerHTML = originalHtml
    }
  }

  #showStatus(message, success) {
    if (!this.hasFileStatusTarget) return

    this.fileStatusTarget.classList.remove("hidden")
    this.fileStatusTarget.classList.remove(
      "border-(--color-success)",
      "bg-(--color-success-light)",
      "text-(--color-success)",
      "border-(--color-danger)",
      "bg-(--color-danger-light)",
      "text-(--color-danger)"
    )

    if (success) {
      this.fileStatusTarget.classList.add("border-(--color-success)", "bg-(--color-success-light)", "text-(--color-success)")
    } else {
      this.fileStatusTarget.classList.add("border-(--color-danger)", "bg-(--color-danger-light)", "text-(--color-danger)")
    }

    this.fileStatusTarget.textContent = message
  }
}
