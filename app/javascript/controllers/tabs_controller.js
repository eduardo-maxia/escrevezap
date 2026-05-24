import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const activeTab = this.tabTargets.find(t => t.getAttribute("aria-selected") === "true")
                   || this.tabTargets.find(t => t.classList.contains("bg-(--color-brand)"))
                   || this.tabTargets[0]
    if (activeTab) {
      this._activateTab(activeTab)
      this._showPanel(activeTab.dataset.tabsTabParam)
    }
  }

  switch(event) {
    const tab = event.currentTarget
    this._activateTab(tab)
    this._showPanel(tab.dataset.tabsTabParam)
  }

  _activateTab(activeTab) {
    this.tabTargets.forEach((tab) => {
      const isActive = tab === activeTab
      tab.setAttribute("aria-selected", isActive ? "true" : "false")

      const activeClasses = (tab.dataset.tabsActiveClass || "").split(/\s+/).filter(Boolean)
      const inactiveClasses = (tab.dataset.tabsInactiveClass || "").split(/\s+/).filter(Boolean)

      if (activeClasses.length || inactiveClasses.length) {
        if (isActive) {
          inactiveClasses.forEach(c => tab.classList.remove(c))
          activeClasses.forEach(c => tab.classList.add(c))
        } else {
          activeClasses.forEach(c => tab.classList.remove(c))
          inactiveClasses.forEach(c => tab.classList.add(c))
        }
      } else {
        // Legacy fallback: solid brand pill
        if (isActive) {
          tab.classList.add("bg-(--color-brand)", "text-(--color-text-inverse)")
          tab.classList.remove("text-(--color-text-muted)", "hover:text-(--color-text)")
        } else {
          tab.classList.remove("bg-(--color-brand)", "text-(--color-text-inverse)")
          tab.classList.add("text-(--color-text-muted)", "hover:text-(--color-text)")
        }
      }
    })
  }

  _showPanel(id) {
    this.panelTargets.forEach((panel) => {
      panel.classList.toggle("hidden", panel.dataset.panelId !== id)
    })
  }
}
