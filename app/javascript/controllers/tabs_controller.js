import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    // Ensure correct initial visibility matches active tab
    const activeTab = this.tabTargets.find(t =>
      t.classList.contains("bg-(--color-brand)")
    )
    const activeId = activeTab?.dataset.tabsTabParam
    if (activeId) this._showPanel(activeId)
  }

  switch(event) {
    const id = event.params.tab
    this._activateTab(event.currentTarget)
    this._showPanel(id)
  }

  _activateTab(activeTab) {
    this.tabTargets.forEach((tab) => {
      if (tab === activeTab) {
        tab.classList.add("bg-(--color-brand)", "text-(--color-text-inverse)")
        tab.classList.remove("text-(--color-text-muted)", "hover:text-(--color-text)")
      } else {
        tab.classList.remove("bg-(--color-brand)", "text-(--color-text-inverse)")
        tab.classList.add("text-(--color-text-muted)", "hover:text-(--color-text)")
      }
    })
  }

  _showPanel(id) {
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.panelId !== id)
    })
  }
}
