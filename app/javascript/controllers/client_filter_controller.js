import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["search", "whatsapp"]

  #timer = null

  // Debounced — triggered on text input
  filter() {
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.#navigate(), 300)
  }

  // Immediate — triggered on select change
  immediate() {
    clearTimeout(this.#timer)
    this.#navigate()
  }

  #navigate() {
    const url = new URL(window.location.href)
    const q = this.searchTarget.value.trim()
    const whatsapp = this.whatsappTarget.value

    if (q) url.searchParams.set("q", q)
    else url.searchParams.delete("q")

    if (whatsapp) url.searchParams.set("whatsapp", whatsapp)
    else url.searchParams.delete("whatsapp")

    url.searchParams.delete("page")

    // Update browser URL + navigate only the turbo-frame
    history.pushState({}, "", url.toString())
    document.getElementById("clients-table").src = url.toString()
  }
}
