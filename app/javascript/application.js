// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "flowbite/dist/flowbite.turbo.js"
import "./controllers"
import "./channels/consumer"

// PWA: capture install prompt before it's consumed by the browser
window.deferredInstallPrompt = null;
window.addEventListener("beforeinstallprompt", (e) => {
  e.preventDefault();
  window.deferredInstallPrompt = e;
  document.dispatchEvent(new CustomEvent("pwa:installable"));
});

window.addEventListener("appinstalled", () => {
  window.deferredInstallPrompt = null;
  document.dispatchEvent(new CustomEvent("pwa:installed"));
});

// Register service worker
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker", { scope: "/" });
  });
}
