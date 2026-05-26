import { Controller } from "@hotwired/stimulus"

// Converts a base64url VAPID public key to a Uint8Array for PushManager.subscribe()
function urlBase64ToUint8Array(base64String) {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
  const raw = atob(base64)
  return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)))
}

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    // Only relevant inside the installed PWA
    const isStandalone =
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true

    if (!isStandalone) return
    if (!("Notification" in window) || !("serviceWorker" in navigator)) return
    if (Notification.permission === "granted") return   // already enabled
    if (Notification.permission === "denied") return    // user blocked it
    if (localStorage.getItem("push_dismissed")) return  // user dismissed banner

    this.hasBannerTarget && this.bannerTarget.classList.remove("hidden")
  }

  async enable() {
    const permission = await Notification.requestPermission()

    if (permission !== "granted") {
      this.hasBannerTarget && this.bannerTarget.classList.add("hidden")
      return
    }

    try {
      const reg = await navigator.serviceWorker.ready
      const vapidKey = document.querySelector("meta[name='vapid-public-key']")?.content
      const subscription = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(vapidKey),
      })

      const keys = subscription.toJSON().keys || {}
      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

      await fetch("/app/push_subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken,
        },
        body: JSON.stringify({
          subscription: {
            endpoint: subscription.endpoint,
            p256dh:   keys.p256dh,
            auth:     keys.auth,
          },
        }),
      })

      this.hasBannerTarget && this.bannerTarget.classList.add("hidden")
    } catch (err) {
      console.error("[push-permission] subscribe failed:", err)
    }
  }

  dismiss() {
    localStorage.setItem("push_dismissed", "1")
    this.hasBannerTarget && this.bannerTarget.classList.add("hidden")
  }
}
