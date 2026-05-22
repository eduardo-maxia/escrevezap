import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="toast"
export default class extends Controller {
  static targets = ["container"];
  static values = {
    position: { type: String, default: "top-right" },
    layout: { type: String, default: "default" },
    gap: { type: Number, default: 14 },
    autoDismissDuration: { type: Number, default: 4500 },
    limit: { type: Number, default: 3 },
  };

  connect() {
    this.toasts = [];
    this.heights = [];
    this.expanded = this.layoutValue === "expanded";
    this.interacting = false;
    this.autoDismissTimers = {};
    this.isPrimaryController = false;
    this.defaultMountParent = this.element?.parentNode || null;
    this.defaultMountNextSibling = this.element?.nextSibling || null;
    this.hoverZonePadding = 10;

    this.registerController();
    this.activatePrimaryIfNeeded();
  }

  updatePositionClasses() {
    const container = this.containerTarget;
    container.classList.remove(
      "right-0", "left-0", "left-1/2", "-translate-x-1/2",
      "top-0", "bottom-0", "mt-4", "mb-4", "mr-4", "ml-4",
      "sm:mt-6", "sm:mb-6", "sm:mr-6", "sm:ml-6",
    );
    const classes = this.positionClasses.split(" ");
    container.classList.add(...classes);
  }

  disconnect() {
    this.unregisterController();
    if (this.autoDismissTimers) {
      Object.values(this.autoDismissTimers).forEach((timer) => clearTimeout(timer));
      this.autoDismissTimers = {};
    }
    this.clearAllToasts();
    if (!this.isPrimaryController) return;
    this.removePrimaryListeners();
    if (window.toast === this.boundShowToast) delete window.toast;
    if (window.__toastPrimaryController === this) window.__toastPrimaryController = null;
    this.isPrimaryController = false;
    this.promoteNextPrimaryController();
  }

  showToast(message, options = {}) {
    const detail = {
      type: options.type || "default",
      message: message,
      description: options.description || "",
      position: options.position || window.currentToastPosition || this.positionValue,
      html: options.html || "",
      action: options.action || null,
      secondaryAction: options.secondaryAction || null,
    };
    window.dispatchEvent(new CustomEvent("toast-show", { detail }));
  }

  handleToastShow(event) {
    if (!this.isPrimaryController) return;
    event.stopPropagation();
    this.ensureGlobalHostVisible();
    if (event.detail.position) {
      this.positionValue = event.detail.position;
      window.currentToastPosition = event.detail.position;
      this.updatePositionClasses();
    }
    const toast = {
      id: `toast-${Math.random().toString(16).slice(2)}`,
      mounted: false,
      removed: false,
      message: event.detail.message,
      description: event.detail.description,
      type: event.detail.type,
      html: event.detail.html,
      action: event.detail.action,
      secondaryAction: event.detail.secondaryAction,
    };
    this.toasts.unshift(toast);
    const activeToasts = this.toasts.filter((t) => !t.removed);
    if (activeToasts.length > this.limitValue) {
      const oldestActiveToast = activeToasts[activeToasts.length - 1];
      if (oldestActiveToast && !oldestActiveToast.removed) {
        this.removeToast(oldestActiveToast.id, true);
      }
    }
    this.renderToast(toast);
  }

  handleLayoutChange(event) {
    if (!this.isPrimaryController) return;
    this.layoutValue = event.detail.layout;
    this.expanded = this.layoutValue === "expanded";
    this.updateAllToasts();
  }

  beforeCache() {
    if (!this.isPrimaryController) return;
    this.clearAllToasts();
    window.currentToastPosition = this.element.dataset.toastPositionValue || "top-right";
  }

  clearAllToasts() {
    const container = this.containerTarget;
    if (container) {
      while (container.firstChild) container.removeChild(container.firstChild);
    }
    this.toasts = [];
    this.heights = [];
    if (this.layoutValue === "default") this.expanded = false;
    if (this.autoDismissTimers) {
      Object.values(this.autoDismissTimers).forEach((timer) => clearTimeout(timer));
      this.autoDismissTimers = {};
    }
    this.hideGlobalHostIfIdle();
  }

  handleMouseEnter() { this.setExpandedState(true); }
  handleMouseLeave() { this.setExpandedState(false); }

  renderToast(toast) {
    this.ensureGlobalHostVisible();
    const container = this.containerTarget;
    const li = this.createToastElement(toast);
    container.insertBefore(li, container.firstChild);

    requestAnimationFrame(() => {
      const toastEl = document.getElementById(toast.id);
      if (toastEl) {
        const height = toastEl.getBoundingClientRect().height;
        this.heights.unshift({ toastId: toast.id, height });
        requestAnimationFrame(() => {
          toast.mounted = true;
          toastEl.dataset.mounted = "true";
          this.updateAllToasts();
        });
        const activeToasts = this.toasts.filter((t) => !t.removed);
        const activeToastIndex = activeToasts.findIndex((t) => t.id === toast.id);
        if (activeToastIndex < this.limitValue) this.scheduleAutoDismiss(toast.id);
      }
    });
  }

  scheduleAutoDismiss(toastId) {
    if (!this.autoDismissTimers) this.autoDismissTimers = {};
    if (this.autoDismissTimers[toastId]) clearTimeout(this.autoDismissTimers[toastId]);
    this.autoDismissTimers[toastId] = setTimeout(() => {
      this.removeToast(toastId);
      delete this.autoDismissTimers[toastId];
    }, this.autoDismissDurationValue);
  }

  createToastElement(toast) {
    const li = document.createElement("li");
    li.id = toast.id;
    li.className = "toast-item sm:max-w-xs";
    li.style.pointerEvents = "auto";
    li.dataset.mounted = "false";
    li.dataset.removed = "false";
    li.dataset.position = this.positionValue;
    li.dataset.expanded = this.expanded.toString();
    li.dataset.visible = "true";
    li.dataset.front = "false";
    li.dataset.index = "0";
    if (!toast.description) li.classList.add("toast-no-description");

    const span = document.createElement("span");
    span.className = `relative flex flex-col items-start shadow-sm w-full transition-all duration-200 toast-card rounded-xl sm:max-w-xs group ${
      toast.html ? "p-0" : "p-4"
    }`;
    span.style.transitionTimingFunction = "cubic-bezier(0.4, 0, 0.2, 1)";

    if (toast.html) {
      span.innerHTML = toast.html;
    } else {
      span.innerHTML = this.getToastHTML(toast);
    }

    if (!toast.html && (toast.action || toast.secondaryAction)) {
      requestAnimationFrame(() => {
        if (toast.action) {
          const primaryBtn = span.querySelector('[data-action-type="primary"]');
          if (primaryBtn) {
            primaryBtn.addEventListener("click", (e) => {
              e.stopPropagation();
              toast.action.onClick();
              this.removeToast(toast.id);
            });
          }
        }
        if (toast.secondaryAction) {
          const secondaryBtn = span.querySelector('[data-action-type="secondary"]');
          if (secondaryBtn) {
            secondaryBtn.addEventListener("click", (e) => {
              e.stopPropagation();
              toast.secondaryAction.onClick();
              this.removeToast(toast.id);
            });
          }
        }
      });
    }

    const closeBtn = document.createElement("span");
    const hasActions = toast.action || toast.secondaryAction;
    closeBtn.className = `absolute right-0 p-1.5 mr-2.5 toast-close-btn duration-100 ease-in-out rounded-full cursor-pointer ${
      !toast.description && !toast.html && !hasActions ? "top-1/2 -translate-y-1/2" : "top-0 mt-2.5"
    }`;
    closeBtn.innerHTML = `<svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"></path></svg>`;
    closeBtn.dataset.toastId = toast.id;
    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      this.removeToast(toast.id);
    });

    span.appendChild(closeBtn);
    li.appendChild(span);
    return li;
  }

  getToastHTML(toast) {
    // Use custom CSS classes that map to our brand palette
    const typeColors = {
      success: "toast-icon-success",
      error:   "toast-icon-danger",
      info:    "toast-icon-info",
      warning: "toast-icon-warning",
      danger:  "toast-icon-danger",
      loading: "text-neutral-500",
      default: "toast-icon-default",
    };

    const color = typeColors[toast.type] || typeColors.default;

    const icons = {
      success: `<svg class="size-4.5 mr-1.5 -ml-1" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18"><g fill="currentColor"><path d="M9,1C4.589,1,1,4.589,1,9s3.589,8,8,8,8-3.589,8-8S13.411,1,9,1Zm3.843,5.708l-4.25,5.5c-.136,.176-.343,.283-.565,.291-.01,0-.019,0-.028,0-.212,0-.415-.09-.558-.248l-2.25-2.5c-.277-.308-.252-.782,.056-1.06,.309-.276,.781-.252,1.06,.056l1.648,1.832,3.685-4.772c.264-.342,.754-.405,1.095-.142,.342,.263,.406,.752,.143,1.094Z"/></g></svg>`,
      error:   `<svg class="size-4.5 mr-1.5 -ml-1" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18"><g fill="currentColor"><path d="M9,1C4.589,1,1,4.589,1,9s3.589,8,8,8,8-3.589,8-8S13.411,1,9,1Zm3.28,10.22c.293,.293,.293,.768,0,1.061-.146,.146-.338,.22-.53,.22s-.384-.073-.53-.22l-2.22-2.22-2.22,2.22c-.146,.146-.338,.22-.53,.22s-.384-.073-.53-.22c-.293-.293-.293-.768,0-1.061l2.22-2.22-2.22-2.22c-.293-.293-.293-.768,0-1.061s.768-.293,1.061,0l2.22,2.22,2.22-2.22c.293-.293,.768-.293,1.061,0s.293,.768,0,1.061l-2.22,2.22,2.22,2.22Z"/></g></svg>`,
      info:    `<svg class="size-4.5 mr-1.5 -ml-1" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18"><g fill="currentColor"><path d="M9 1C4.5889 1 1 4.5889 1 9C1 13.4111 4.5889 17 9 17C13.4111 17 17 13.4111 17 9C17 4.5889 13.4111 1 9 1ZM9.75 12.75C9.75 13.1641 9.4141 13.5 9 13.5C8.5859 13.5 8.25 13.1641 8.25 12.75V9.5H7.75C7.3359 9.5 7 9.1641 7 8.75C7 8.3359 7.3359 8 7.75 8H9C9.4141 8 9.75 8.3359 9.75 8.75V12.75ZM9 6.5C8.4478 6.5 8 6.0522 8 5.5C8 4.9478 8.4478 4.5 9 4.5C9.5522 4.5 10 4.9478 10 5.5C10 6.0522 9.5522 6.5 9 6.5Z"/></g></svg>`,
      warning: `<svg class="size-4.5 mr-1.5 -ml-1" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18"><g fill="currentColor"><path d="M16.4364 12.5151L11.0101 3.11316C10.5902 2.39096 9.83872 1.96045 8.99982 1.96045C8.16092 1.96045 7.40952 2.39106 6.98952 3.11316L1.56372 12.5156C1.14332 13.2436 1.14332 14.1128 1.56372 14.8398C1.98462 15.5688 2.73662 15.9998 3.57452 15.9998H14.4281C15.266 15.9998 16.018 15.5688 16.4389 14.8398C16.8578 14.1108 16.8568 13.2421 16.4364 12.5151ZM8.25 6.75C8.25 6.336 8.586 6 9 6C9.414 6 9.75 6.336 9.75 6.75V10.25C9.75 10.664 9.414 11 9 11C8.586 11 8.25 10.664 8.25 10.25V6.75ZM9 14C8.448 14 8 13.552 8 13C8 12.448 8.448 12 9 12C9.552 12 10 12.448 10 13C10 13.552 9.552 14 9 14Z"/></g></svg>`,
      loading: `<svg class="size-4.5 mr-1.5 -ml-1 animate-spin" xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18"><g fill="currentColor"><path d="m9,17c-4.4111,0-8-3.5889-8-8S4.5889,1,9,1s8,3.5889,8,8-3.5889,8-8,8Zm0-14.5c-3.584,0-6.5,2.916-6.5,6.5s2.916,6.5,6.5,6.5,6.5-2.916,6.5-6.5-2.916-6.5-6.5-6.5Z" opacity=".4" stroke-width="0"></path><path d="m15.2754,5.3125c.2998-.5181,.1226-1.1797-.3916-1.4849C13.2305,2.7153,11.1816,2,9,2c-.4141,0-.75,.3359-.75,.75s.3359,.75,.75,.75c1.9297,0,3.7197,.6201,5.3848,1.8926,.1523,.1118,.3262,.1655,.499,.1655,.376,0,.7441-.1914,.9316-.5356Z" stroke-width="0"></path></g></svg>`,
    };

    const icon = icons[toast.type] || "";
    const hasActions = toast.action || toast.secondaryAction;
    const actionsHTML = hasActions
      ? `<div></div>
        <div class="flex justify-end items-center gap-2 mt-0.5">
          ${toast.secondaryAction ? `<button data-action-type="secondary" class="flex items-center justify-center gap-1.5 rounded-lg border border-neutral-200 bg-white/90 px-2 py-1.5 text-xs font-medium whitespace-nowrap text-neutral-800 shadow-xs transition-all duration-100 ease-in-out select-none hover:bg-neutral-50">${toast.secondaryAction.label}</button>` : ""}
          ${toast.action ? `<button data-action-type="primary" class="flex items-center justify-center gap-1.5 rounded-lg bg-brand px-2 py-1.5 text-xs font-medium whitespace-nowrap text-white shadow-sm transition-all duration-100 ease-in-out select-none hover:bg-brand-dark">${toast.action.label}</button>` : ""}
        </div>`
      : "";

    return `
      <div class="relative w-full">
        <div class="grid grid-cols-[auto_1fr] gap-y-1.5 items-start">
          <div class="flex items-center h-full ${color}">
            ${icon}
          </div>
          <p class="text-[13px] font-medium toast-message-text pr-6">
            ${toast.message}
          </p>
          ${toast.description ? `<div></div><div class="text-xs toast-desc-text">${toast.description}</div>` : ""}
          ${actionsHTML}
        </div>
      </div>
    `;
  }

  removeToast(id, isOverflow = false) {
    const toast = this.toasts.find((t) => t.id === id);
    if (!toast || toast.removed) return;
    const toastEl = document.getElementById(id);
    if (!toastEl) return;
    toast.removed = true;
    toastEl.dataset.removed = "true";
    if (isOverflow) toastEl.dataset.overflow = "true";
    if (this.autoDismissTimers && this.autoDismissTimers[id]) {
      clearTimeout(this.autoDismissTimers[id]);
      delete this.autoDismissTimers[id];
    }
    setTimeout(() => {
      this.toasts = this.toasts.filter((t) => t.id !== id);
      this.heights = this.heights.filter((h) => h.toastId !== id);
      if (toastEl.parentNode) toastEl.parentNode.removeChild(toastEl);
      this.updateAllToasts();
      this.hideGlobalHostIfIdle();
      if (this.toasts.length >= this.limitValue) {
        const newlyVisibleToast = this.toasts[this.limitValue - 1];
        if (newlyVisibleToast && !this.autoDismissTimers[newlyVisibleToast.id]) {
          this.scheduleAutoDismiss(newlyVisibleToast.id);
        }
      }
    }, 400);
  }

  updateAllToasts() {
    requestAnimationFrame(() => {
      const visibleToasts = this.limitValue;
      let visualIndex = 0;
      this.toasts.forEach((toast, index) => {
        const toastEl = document.getElementById(toast.id);
        if (!toastEl) return;
        if (toast.removed && toastEl.dataset.overflow === "true") {
          toastEl.dataset.index = String(this.limitValue - 1);
          toastEl.dataset.visible = "true";
          toastEl.dataset.expanded = this.expanded.toString();
          toastEl.dataset.position = this.positionValue;
          toastEl.style.setProperty("--toast-z-index", 0);
          toastEl.style.setProperty("--toast-index", this.limitValue - 1);
          return;
        }
        if (toast.removed) return;
        const isVisible = visualIndex < visibleToasts;
        const isFront = visualIndex === 0;
        let offset = 0;
        for (let i = 0; i < index; i++) {
          if (this.toasts[i].removed) continue;
          const heightInfo = this.heights.find((h) => h.toastId === this.toasts[i].id);
          if (heightInfo) offset += heightInfo.height + this.gapValue;
        }
        toastEl.dataset.expanded = this.expanded.toString();
        toastEl.dataset.visible = isVisible.toString();
        toastEl.dataset.front = isFront.toString();
        toastEl.dataset.index = visualIndex.toString();
        toastEl.dataset.position = this.positionValue;
        toastEl.style.setProperty("--toast-z-index", 100 - visualIndex);
        toastEl.style.setProperty("--toast-offset", `${offset}px`);
        toastEl.style.setProperty("--toast-index", visualIndex);
        const heightInfo = this.heights.find((h) => h.toastId === toast.id);
        if (heightInfo) toastEl.style.setProperty("--initial-height", `${heightInfo.height}px`);
        if (!this.expanded) {
          const frontHeight = this.heights[0]?.height || 0;
          toastEl.style.setProperty("--front-toast-height", `${frontHeight}px`);
        } else {
          toastEl.style.removeProperty("--front-toast-height");
        }
        visualIndex++;
      });
      this.updateContainerHeight();
      setTimeout(() => this.updateContainerHeight(), 400);
    });
  }

  updateContainerHeight() {
    const activeToasts = this.toasts.filter((t) => !t.removed);
    if (activeToasts.length === 0) {
      this.containerTarget.style.height = "0px";
      this.hideGlobalHostIfIdle();
      return;
    }
    if (this.expanded) {
      let totalHeight = 0;
      const visibleToasts = Math.min(activeToasts.length, this.limitValue);
      for (let i = 0; i < visibleToasts; i++) {
        const heightInfo = this.heights.find((h) => h.toastId === activeToasts[i].id);
        if (heightInfo) {
          totalHeight += heightInfo.height;
          if (i < visibleToasts - 1) totalHeight += this.gapValue;
        }
      }
      this.containerTarget.style.height = totalHeight + "px";
    } else {
      const frontToast = activeToasts[0];
      const frontHeight = frontToast ? this.heights.find((h) => h.toastId === frontToast.id)?.height || 0 : 0;
      const visibleCount = Math.min(activeToasts.length, this.limitValue);
      this.containerTarget.style.height = frontHeight + 24 * (visibleCount - 1) + "px";
    }
  }

  get positionClasses() {
    const positions = {
      "top-right":     "right-0 top-0 mt-4 mr-4 sm:mt-6 sm:mr-6",
      "top-left":      "left-0 top-0 mt-4 ml-4 sm:mt-6 sm:ml-6",
      "top-center":    "left-1/2 -translate-x-1/2 top-0 mt-4 sm:mt-6",
      "bottom-right":  "right-0 bottom-0 mb-4 mr-4 sm:mr-6 sm:mb-6",
      "bottom-left":   "left-0 bottom-0 mb-4 ml-4 sm:ml-6 sm:mb-6",
      "bottom-center": "left-1/2 -translate-x-1/2 bottom-0 mb-4 sm:mb-6",
    };
    return positions[this.positionValue] || positions["top-right"];
  }

  registerController() {
    if (!window.__toastControllers) window.__toastControllers = new Set();
    window.__toastControllers.add(this);
  }

  unregisterController() {
    if (window.__toastControllers) window.__toastControllers.delete(this);
  }

  activatePrimaryIfNeeded() {
    const existingPrimary = window.__toastPrimaryController;
    const existingPrimaryConnected = existingPrimary?.element?.isConnected;
    if (existingPrimary && existingPrimary !== this && existingPrimaryConnected) return;
    this.becomePrimaryController();
  }

  becomePrimaryController() {
    if (this.isPrimaryController) return;
    this.isPrimaryController = true;
    window.__toastPrimaryController = this;
    this.initializePositionState();
    this.updatePositionClasses();
    this.mountToGlobalHost();
    this.applyPointerEventPolicy();
    this.boundShowToast = this.showToast.bind(this);
    window.toast = this.boundShowToast;
    this.boundHandleToastShow = this.handleToastShow.bind(this);
    this.boundHandleLayoutChange = this.handleLayoutChange.bind(this);
    this.boundBeforeCache = this.beforeCache.bind(this);
    this.boundPointerMove = this.handleGlobalPointerMove.bind(this);
    this.boundPointerLeave = this.handleGlobalPointerLeave.bind(this);
    this.boundHandleDialogStateChange = this.handleDialogStateChange.bind(this);
    window.addEventListener("toast-show", this.boundHandleToastShow);
    window.addEventListener("set-toasts-layout", this.boundHandleLayoutChange);
    window.addEventListener("pointermove", this.boundPointerMove, { passive: true });
    window.addEventListener("pointerleave", this.boundPointerLeave);
    window.addEventListener("blur", this.boundPointerLeave);
    document.addEventListener("turbo:before-cache", this.boundBeforeCache);
    this.startDialogStateObserver();
  }

  removePrimaryListeners() {
    if (this.boundHandleToastShow) window.removeEventListener("toast-show", this.boundHandleToastShow);
    if (this.boundHandleLayoutChange) window.removeEventListener("set-toasts-layout", this.boundHandleLayoutChange);
    if (this.boundPointerMove) window.removeEventListener("pointermove", this.boundPointerMove);
    if (this.boundPointerLeave) {
      window.removeEventListener("pointerleave", this.boundPointerLeave);
      window.removeEventListener("blur", this.boundPointerLeave);
    }
    if (this.boundBeforeCache) document.removeEventListener("turbo:before-cache", this.boundBeforeCache);
    this.stopDialogStateObserver();
  }

  promoteNextPrimaryController() {
    if (!window.__toastControllers?.size) return;
    const nextPrimary = Array.from(window.__toastControllers).find((c) => c?.element?.isConnected);
    if (nextPrimary) nextPrimary.becomePrimaryController();
  }

  initializePositionState() {
    if (!window.currentToastPosition) {
      window.currentToastPosition = this.positionValue;
      return;
    }
    this.positionValue = window.currentToastPosition;
  }

  mountToGlobalHost() {
    this.globalHost = this.element;
    if (!this.globalHost) return;
    if (typeof this.globalHost.showPopover === "function" && !this.globalHost.hasAttribute("popover")) {
      this.globalHost.setAttribute("popover", "manual");
    }
    const mountRoot = this.preferredMountRoot();
    if (!mountRoot) return;
    if (this.globalHost.parentNode !== mountRoot) {
      try { if (this.globalHost.matches(":popover-open")) this.globalHost.hidePopover(); } catch {}
      if (mountRoot === this.defaultMountParent && this.defaultMountNextSibling?.parentNode === mountRoot) {
        mountRoot.insertBefore(this.globalHost, this.defaultMountNextSibling);
      } else {
        mountRoot.appendChild(this.globalHost);
      }
    }
  }

  preferredMountRoot() {
    const openDialog = this.topmostOpenDialog();
    if (openDialog) return openDialog;
    const parentDialog = this.defaultMountParent instanceof Element ? this.defaultMountParent.closest("dialog") : null;
    if (parentDialog && !parentDialog.open) return document.body;
    if (this.defaultMountParent?.tagName === "DIALOG" && !this.defaultMountParent.open) return document.body;
    return this.defaultMountParent || document.body;
  }

  topmostOpenDialog() {
    const openDialogs = Array.from(document.querySelectorAll("dialog[open]")).filter((d) => d.isConnected);
    return openDialogs.length === 0 ? null : openDialogs[openDialogs.length - 1];
  }

  applyPointerEventPolicy() {
    if (this.element) this.element.style.pointerEvents = "none";
    if (this.hasContainerTarget) this.containerTarget.style.pointerEvents = "none";
  }

  ensureGlobalHostVisible() {
    this.mountToGlobalHost();
    if (!this.globalHost || typeof this.globalHost.showPopover !== "function") return;
    try { if (this.globalHost.matches(":popover-open")) this.globalHost.hidePopover(); } catch {}
    try { this.globalHost.showPopover(); } catch {}
  }

  hideGlobalHostIfIdle() {
    if (!this.globalHost || typeof this.globalHost.hidePopover !== "function") return;
    if (this.toasts.some((toast) => !toast.removed)) return;
    try { if (this.globalHost.matches(":popover-open")) this.globalHost.hidePopover(); } catch {}
  }

  startDialogStateObserver() {
    if (this.dialogStateObserver || !document.body) return;
    this.dialogStateObserver = new MutationObserver(this.boundHandleDialogStateChange);
    this.dialogStateObserver.observe(document.body, { subtree: true, childList: true, attributes: true, attributeFilter: ["open"] });
  }

  stopDialogStateObserver() {
    if (!this.dialogStateObserver) return;
    this.dialogStateObserver.disconnect();
    this.dialogStateObserver = null;
  }

  handleDialogStateChange() {
    if (!this.isPrimaryController) return;
    this.mountToGlobalHost();
    if (this.toasts.some((t) => !t.removed)) this.ensureGlobalHostVisible();
    else this.hideGlobalHostIfIdle();
  }

  setExpandedState(nextExpanded) {
    if (this.layoutValue !== "default") return;
    if (nextExpanded === this.expanded) return;
    if (!nextExpanded && this.interacting) return;
    this.expanded = nextExpanded;
    this.updateAllToasts();
  }

  handleGlobalPointerMove(event) {
    if (!this.isPrimaryController || !this.hasContainerTarget) return;
    if (!this.toasts.some((toast) => !toast.removed)) { this.setExpandedState(false); return; }
    this.setExpandedState(this.isInHoverZone(event.clientX, event.clientY));
  }

  handleGlobalPointerLeave() {
    if (!this.isPrimaryController) return;
    this.setExpandedState(false);
  }

  isInHoverZone(clientX, clientY) {
    const rect = this.containerTarget.getBoundingClientRect();
    const pad = this.hoverZonePadding;
    return clientX >= rect.left - pad && clientX <= rect.right + pad && clientY >= rect.top - pad && clientY <= rect.bottom + pad;
  }
}

