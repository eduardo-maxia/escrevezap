// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
import "flowbite/dist/flowbite.turbo.js"
import "./controllers"
import "./channels/consumer"

// Custom confirm dialog replacing the native browser confirm()
Turbo.config.confirmMethod = (message) => {
  return new Promise((resolve) => {
    const dialog = document.createElement("dialog")
    dialog.className = "app-modal md:max-w-sm"
    dialog.innerHTML = `
      <div class="app-modal-handle"></div>
      <div style="padding:1.25rem 1.5rem 1.5rem;display:flex;flex-direction:column;gap:1rem">
        <div style="display:flex;align-items:flex-start;gap:0.75rem">
          <div style="width:2.25rem;height:2.25rem;border-radius:9999px;background:var(--color-danger-light);display:flex;align-items:center;justify-content:center;flex-shrink:0">
            <i class="ph ph-warning-circle" style="color:var(--color-danger);font-size:1.125rem"></i>
          </div>
          <div style="flex:1;padding-top:0.125rem">
            <p style="font-size:0.875rem;font-weight:700;color:var(--color-text)">Confirmar ação</p>
            <p style="font-size:0.875rem;color:var(--color-text-muted);margin-top:0.25rem">${message}</p>
          </div>
        </div>
        <div style="display:flex;gap:0.5rem;justify-content:flex-end;padding-top:0.25rem">
          <button data-confirm-action="cancel"
            style="padding:0.5rem 1rem;font-size:0.875rem;font-weight:500;color:var(--color-text-muted);border:1px solid var(--color-border);border-radius:0.5rem;background:transparent;cursor:pointer">
            Cancelar
          </button>
          <button data-confirm-action="confirm"
            style="padding:0.5rem 1rem;font-size:0.875rem;font-weight:500;background:var(--color-danger);color:#fff;border:none;border-radius:0.5rem;cursor:pointer">
            Confirmar
          </button>
        </div>
      </div>
    `
    document.body.appendChild(dialog)
    dialog.showModal()

    const cleanup = (result) => { dialog.close(); dialog.remove(); resolve(result) }
    dialog.querySelector("[data-confirm-action='confirm']").addEventListener("click", () => cleanup(true))
    dialog.querySelector("[data-confirm-action='cancel']").addEventListener("click", () => cleanup(false))
    dialog.addEventListener("cancel", () => cleanup(false)) // ESC key
  })
}

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
