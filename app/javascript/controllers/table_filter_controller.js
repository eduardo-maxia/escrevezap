import { Controller } from "@hotwired/stimulus"

// Generic filter controller for any paginated turbo-frame table.
// Usage:
//   data-controller="table-filter"
//   data-table-filter-frame-value="frame-id"
//   data-table-filter-page-param-value="page_param_name"   (default: "page")
//
// Each filter input/select needs:
//   name="param_name"
//   data-table-filter-target="input"
//   data-action="input->table-filter#filter"    (text — debounced)
//   data-action="change->table-filter#immediate" (select — instant)

export default class extends Controller {
  static targets = ["input"]
  static values  = {
    frame:     String,
    pageParam: { type: String, default: "page" }
  }

  #timer = null

  filter() {
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.#navigate(), 300)
  }

  immediate() {
    clearTimeout(this.#timer)
    this.#navigate()
  }

  #navigate() {
    const url = new URL(window.location.href)

    this.inputTargets.forEach(el => {
      const key = el.name
      if (!key) return
      const val = typeof el.value === "string" ? el.value.trim() : el.value
      if (val) url.searchParams.set(key, val)
      else url.searchParams.delete(key)
    })

    // Reset to first page on filter change
    url.searchParams.delete(this.pageParamValue)

    history.pushState({}, "", url.toString())
    document.getElementById(this.frameValue).src = url.toString()
  }
}
