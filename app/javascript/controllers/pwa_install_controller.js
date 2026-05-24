import { Controller } from "@hotwired/stimulus"

// Manages the PWA install prompt.
// Usage: data-controller="pwa-install" on any container.
// The element itself acts as the install trigger button.
//
// The controller hides itself when:
//   - Already running in standalone mode (app already installed)
//   - The install prompt hasn't been captured yet
//
// It shows itself when:
//   - The beforeinstallprompt event fires (captured in application.js)

export default class extends Controller {
  connect() {
    // Already installed → never show
    if (this.#isStandalone()) {
      this.element.hidden = true;
      return;
    }

    // Check if prompt is already available (captured before controller mounted)
    if (window.deferredInstallPrompt) {
      this.element.hidden = false;
    } else {
      this.element.hidden = true;
    }

    this.#onInstallable = () => {
      this.element.hidden = false;
    };
    this.#onInstalled = () => {
      this.element.hidden = true;
    };

    document.addEventListener("pwa:installable", this.#onInstallable);
    document.addEventListener("pwa:installed", this.#onInstalled);
  }

  disconnect() {
    document.removeEventListener("pwa:installable", this.#onInstallable);
    document.removeEventListener("pwa:installed", this.#onInstalled);
  }

  async install(event) {
    event.preventDefault();
    const prompt = window.deferredInstallPrompt;
    if (!prompt) return;

    await prompt.prompt();
    const { outcome } = await prompt.userChoice;

    if (outcome === "accepted") {
      window.deferredInstallPrompt = null;
      this.element.hidden = true;
    }
  }

  // ── Private ────────────────────────────────────────────────────────

  #onInstallable = null;
  #onInstalled   = null;

  #isStandalone() {
    return (
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true
    );
  }
}
