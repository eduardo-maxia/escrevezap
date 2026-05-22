import { Controller } from "@hotwired/stimulus"

// BRL currency mask for a cents-based amount input.
// User types digits only; last 2 digits = cents, rest = reais.
// e.g. typing "15000" → display "150,00", hidden "150.00"
//
// Usage:
//   data-controller="amount-input"
//   Display: data-amount-input-target="display"  (no name — not submitted)
//   Hidden:  data-amount-input-target="hidden"   name="campaign_client[amount]"

export default class extends Controller {
  static targets = ["display", "hidden"]

  connect() {
    const val = parseFloat(this.hiddenTarget.value)
    if (!isNaN(val) && val > 0) {
      this.displayTarget.value = val.toLocaleString("pt-BR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
      })
    }
  }

  format() {
    const digits = this.displayTarget.value.replace(/\D/g, "")
    const cents  = parseInt(digits || "0", 10)

    if (cents === 0) {
      this.displayTarget.value = ""
      this.hiddenTarget.value  = ""
      return
    }

    const amount = cents / 100
    this.displayTarget.value = amount.toLocaleString("pt-BR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
    this.hiddenTarget.value = amount.toFixed(2)
  }
}
