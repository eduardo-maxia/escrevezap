import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

const STATUS_ORDER = ["pending", "sending", "sent", "delivered"]

export default class extends Controller {
  static values = {
    notificationId: Number,
    currentStatus: String
  }

  static targets = ["step", "connector", "completeSection", "failedBanner", "skipLink", "trackingArea"]

  connect() {
    this._applyStatus(this.currentStatusValue)

    this._subscription = consumer.subscriptions.create(
      { channel: "NotificationStatusChannel", notification_id: this.notificationIdValue },
      { received: (data) => this._applyStatus(data.status) }
    )
  }

  disconnect() {
    this._subscription?.unsubscribe()
  }

  _applyStatus(status) {
    if (status === "read") status = "delivered"

    if (status === "failed") {
      if (this.hasFailedBannerTarget) this.failedBannerTarget.classList.remove("hidden")
      return
    }

    const doneIndex = STATUS_ORDER.indexOf(status)

    this.stepTargets.forEach((el) => {
      const step = el.dataset.step
      const stepIndex = STATUS_ORDER.indexOf(step)

      if (stepIndex < doneIndex) {
        el.dataset.state = "done"
      } else if (stepIndex === doneIndex) {
        el.dataset.state = "active"
      } else {
        el.dataset.state = "waiting"
      }
    })

    this.connectorTargets.forEach((el) => {
      const stepIndex = STATUS_ORDER.indexOf(el.dataset.step)
      el.dataset.state = stepIndex < doneIndex ? "done" : "waiting"
    })

    if (status === "delivered") {
      if (this.hasTrackingAreaTarget) this.trackingAreaTarget.classList.add("hidden")
      if (this.hasCompleteSectionTarget) this.completeSectionTarget.classList.remove("hidden")
      if (this.hasSkipLinkTarget) this.skipLinkTarget.classList.add("hidden")
    }
  }
}
