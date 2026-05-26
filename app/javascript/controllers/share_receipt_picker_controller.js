import { Controller } from "@hotwired/stimulus"

const SHARED_CACHE = "shared-receipts"

export default class extends Controller {
  static targets = ["fileStatus"]

  async connect() {
    this.token = new URLSearchParams(window.location.search).get("token")
    if (!this.token) return // no shared file — list is still browsable but attach will show error

    try {
      const cache = await caches.open(SHARED_CACHE)
      const response = await cache.match(`/__shared/${this.token}`)

      if (!response) {
        this.#showError("O comprovante não foi encontrado no dispositivo. Tente compartilhar novamente.")
        return
      }

      this.fileBlob = await response.blob()
      this.fileName = decodeURIComponent(response.headers.get("X-Filename") || "comprovante")
    } catch {
      this.#showError("Não foi possível acessar o arquivo compartilhado. Tente novamente.")
    }
  }

  search(event) {
    clearTimeout(this.#searchTimer)
    this.#searchTimer = setTimeout(() => event.target.form.requestSubmit(), 350)
  }

  async attach(event) {
    const installmentId = event.params.installmentId
    const markPaid = event.params.markPaid === true || event.params.markPaid === "true"

    if (!this.fileBlob) {
      this.#showError("Arquivo indisponível. Compartilhe novamente o comprovante.")
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
      this.#showError(error.message || "Falha ao salvar comprovante.")
      button.disabled = false
      button.innerHTML = originalHtml
    }
  }

  // ── Private ────────────────────────────────────────────────
  #searchTimer = null

  #showError(message) {
    if (!this.hasFileStatusTarget) return
    const el = this.fileStatusTarget
    el.className = "rounded-xl border border-(--color-danger) bg-(--color-danger-light) px-4 py-3 text-sm text-(--color-danger) flex items-center gap-2"
    el.innerHTML = `<i class="ph ph-warning-circle flex-shrink-0"></i><span>${message}</span>`
  }
}
