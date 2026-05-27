import { Controller } from "@hotwired/stimulus"

// Records up to MAX_SECONDS of audio from the browser microphone, uploads it
// to /testar-transcricao and renders the result in a Pro-style WhatsApp bubble.
//
// States: idle → requesting → recording → uploading → result / error

const MAX_SECONDS = 10

export default class extends Controller {
  static targets = [
    "recordBtn", "recordIcon", "recordLabel",
    "timer", "progress",
    "status",
    "result", "summaryBlock", "summaryText", "formattedText",
    "error", "errorText",
    "retry"
  ]

  static values = {
    url: String
  }

  connect() {
    this._mediaRecorder = null
    this._stream        = null
    this._chunks        = []
    this._tickTimer     = null
    this._stopTimer     = null
    this._startedAt     = 0
    this._state         = "idle"
  }

  disconnect() {
    this._teardownStream()
    this._clearTimers()
  }

  // ── Public actions ──────────────────────────────────────────────────────

  async toggle(event) {
    event?.preventDefault()
    if (this._state === "recording") {
      this._stopRecording()
    } else if (this._state === "idle" || this._state === "error" || this._state === "result") {
      await this._startRecording()
    }
  }

  reset(event) {
    event?.preventDefault()
    this._resetUI()
    this._setState("idle")
  }

  // ── Recording ───────────────────────────────────────────────────────────

  async _startRecording() {
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === "undefined") {
      this._showError("Seu navegador não suporta gravação de áudio. Tente no Chrome ou Safari atualizado.")
      return
    }

    this._resetUI()
    this._setState("requesting")
    this._setStatus("Liberando microfone...")

    try {
      this._stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (err) {
      this._showError("Precisamos da permissão do microfone para transcrever seu áudio.")
      return
    }

    const mimeType = this._pickMimeType()
    try {
      this._mediaRecorder = new MediaRecorder(this._stream, mimeType ? { mimeType } : undefined)
    } catch (err) {
      this._showError("Não foi possível iniciar a gravação neste navegador.")
      this._teardownStream()
      return
    }

    this._chunks = []
    this._mediaRecorder.ondataavailable = (e) => { if (e.data && e.data.size > 0) this._chunks.push(e.data) }
    this._mediaRecorder.onstop = () => this._handleStop()

    this._mediaRecorder.start()
    this._startedAt = Date.now()
    this._setState("recording")
    this._setStatus("Gravando... fale agora")
    this._tickTimer = setInterval(() => this._tick(), 100)
    this._stopTimer = setTimeout(() => this._stopRecording(), MAX_SECONDS * 1000)
  }

  _stopRecording() {
    if (this._mediaRecorder && this._mediaRecorder.state !== "inactive") {
      this._mediaRecorder.stop()
    }
    this._clearTimers()
  }

  async _handleStop() {
    this._teardownStream()
    const mimeType = this._mediaRecorder?.mimeType || "audio/webm"
    const blob = new Blob(this._chunks, { type: mimeType })
    this._chunks = []

    if (blob.size === 0) {
      this._showError("Não detectamos áudio. Tente novamente.")
      return
    }

    await this._upload(blob, mimeType)
  }

  // ── Upload ──────────────────────────────────────────────────────────────

  async _upload(blob, mimeType) {
    this._setState("uploading")
    this._setStatus("Transcrevendo seu áudio...")

    const form = new FormData()
    const ext  = this._extensionFor(mimeType)
    form.append("audio", blob, `demo${ext}`)

    let response
    try {
      response = await fetch(this.urlValue, {
        method:  "POST",
        body:    form,
        headers: { "X-CSRF-Token": this._csrfToken(), "Accept": "application/json" }
      })
    } catch (err) {
      this._showError("Falha de conexão. Verifique sua internet e tente de novo.")
      return
    }

    let payload = {}
    try { payload = await response.json() } catch (_) { /* ignore */ }

    if (!response.ok) {
      this._showError(payload.error || "Não foi possível processar o áudio.")
      return
    }

    this._renderResult(payload)
  }

  // ── UI rendering ────────────────────────────────────────────────────────

  _renderResult({ summary, full_formatted }) {
    this._setState("result")
    this._setStatus("")

    if (summary && summary.trim().length > 0) {
      this.summaryTextTarget.textContent = summary
      this.summaryBlockTarget.classList.remove("hidden")
    } else {
      this.summaryBlockTarget.classList.add("hidden")
    }

    this.formattedTextTarget.innerHTML = this._formatBody(full_formatted || "")
    this.resultTarget.classList.remove("hidden")
    this.errorTarget.classList.add("hidden")

    if (this.hasRecordIconTarget) this.recordIconTarget.className = "ph ph-arrow-counter-clockwise text-2xl"
    if (this.hasRecordLabelTarget) this.recordLabelTarget.textContent = "Gravar novamente"
  }

  _showError(message) {
    this._setState("error")
    this._setStatus("")
    this._teardownStream()
    this._clearTimers()

    if (this.hasErrorTextTarget) this.errorTextTarget.textContent = message
    if (this.hasErrorTarget)     this.errorTarget.classList.remove("hidden")
    if (this.hasResultTarget)    this.resultTarget.classList.add("hidden")

    if (this.hasRecordIconTarget) this.recordIconTarget.className = "ph ph-microphone text-2xl"
    if (this.hasRecordLabelTarget) this.recordLabelTarget.textContent = "Tentar novamente"
  }

  _resetUI() {
    if (this.hasResultTarget) this.resultTarget.classList.add("hidden")
    if (this.hasErrorTarget)  this.errorTarget.classList.add("hidden")
    if (this.hasTimerTarget)  this.timerTarget.textContent = "0,0s"
    if (this.hasProgressTarget) this.progressTarget.style.width = "0%"
  }

  _setState(state) {
    this._state = state
    this.element.dataset.state = state

    if (this.hasRecordBtnTarget) {
      const disabled = state === "requesting" || state === "uploading"
      this.recordBtnTarget.disabled = disabled
      this.recordBtnTarget.classList.toggle("opacity-60", disabled)
      this.recordBtnTarget.classList.toggle("cursor-not-allowed", disabled)
    }

    if (this.hasRecordIconTarget && this.hasRecordLabelTarget) {
      if (state === "recording") {
        this.recordIconTarget.className = "ph-fill ph-stop text-2xl"
        this.recordLabelTarget.textContent = "Parar gravação"
      } else if (state === "idle") {
        this.recordIconTarget.className = "ph ph-microphone text-2xl"
        this.recordLabelTarget.textContent = "Gravar áudio"
      }
    }
  }

  _setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  _tick() {
    const elapsed = (Date.now() - this._startedAt) / 1000
    const capped  = Math.min(elapsed, MAX_SECONDS)
    if (this.hasTimerTarget) this.timerTarget.textContent = `${capped.toFixed(1).replace(".", ",")}s`
    if (this.hasProgressTarget) this.progressTarget.style.width = `${(capped / MAX_SECONDS) * 100}%`
  }

  _clearTimers() {
    if (this._tickTimer) { clearInterval(this._tickTimer); this._tickTimer = null }
    if (this._stopTimer) { clearTimeout(this._stopTimer); this._stopTimer = null }
  }

  _teardownStream() {
    if (this._stream) {
      this._stream.getTracks().forEach(t => t.stop())
      this._stream = null
    }
  }

  _csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  _pickMimeType() {
    const candidates = ["audio/webm;codecs=opus", "audio/webm", "audio/ogg;codecs=opus", "audio/mp4"]
    for (const c of candidates) {
      if (typeof MediaRecorder !== "undefined" && MediaRecorder.isTypeSupported && MediaRecorder.isTypeSupported(c)) {
        return c
      }
    }
    return ""
  }

  _extensionFor(mimeType) {
    if (mimeType.includes("webm")) return ".webm"
    if (mimeType.includes("ogg"))  return ".ogg"
    if (mimeType.includes("mp4"))  return ".m4a"
    return ".webm"
  }

  // Renders WhatsApp-style *bold* into <strong>, preserving newlines.
  _formatBody(text) {
    const escaped = text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
    const bolded = escaped.replace(/\*([^*\n]+)\*/g, "<strong>$1</strong>")
    return bolded.replace(/\n/g, "<br>")
  }
}
