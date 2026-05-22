import { Controller } from "@hotwired/stimulus"
import {
  Chart,
  LineController,
  LineElement,
  PointElement,
  LinearScale,
  CategoryScale,
  Filler,
  Tooltip
} from "chart.js"

Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Filler, Tooltip)

const PALETTES = {
  receita: {
    borderColor: "rgba(34, 197, 94, 1)",
    backgroundColor: "rgba(34, 197, 94, 0.12)"
  },
  clientes: {
    borderColor: "rgba(59, 130, 246, 1)",
    backgroundColor: "rgba(59, 130, 246, 0.12)"
  },
  inadimplencia: {
    borderColor: "rgba(249, 115, 22, 1)",
    backgroundColor: "rgba(249, 115, 22, 0.12)"
  }
}

function formatValue(metric, value) {
  if (metric === "clientes") return value
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    minimumFractionDigits: 2
  }).format(value)
}

export default class extends Controller {
  static targets = ["canvas", "btn"]
  static values  = { data: Object, metric: { type: String, default: "receita" } }

  connect() {
    this._buildChart()
  }

  disconnect() {
    this._chart?.destroy()
  }

  setMetric(event) {
    const metric = event.currentTarget.dataset.metric
    this.metricValue = metric
    this._updateActiveBtn(event.currentTarget)
    this._updateChart()
  }

  _buildChart() {
    const ctx = this.canvasTarget.getContext("2d")
    const metric = this.metricValue
    const { labels } = this.dataValue
    const data = this.dataValue[metric] || []
    const palette = PALETTES[metric] || PALETTES.receita

    this._chart = new Chart(ctx, {
      type: "line",
      data: {
        labels,
        datasets: [{
          data,
          tension: 0.35,
          fill: true,
          borderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6,
          ...palette
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => " " + formatValue(metric, ctx.parsed.y)
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { color: "#9ca3af", font: { size: 12 } }
          },
          y: {
            beginAtZero: true,
            grid: { color: "rgba(156, 163, 175, 0.15)" },
            ticks: {
              color: "#9ca3af",
              font: { size: 12 },
              callback: (value) => formatValue(metric, value)
            }
          }
        }
      }
    })
  }

  _updateChart() {
    if (!this._chart) return
    const metric = this.metricValue
    const data   = this.dataValue[metric] || []
    const palette = PALETTES[metric] || PALETTES.receita

    this._chart.data.datasets[0].data = data
    Object.assign(this._chart.data.datasets[0], palette)

    // Update tooltip and y-axis formatter to match new metric
    this._chart.options.plugins.tooltip.callbacks.label = (ctx) =>
      " " + formatValue(metric, ctx.parsed.y)
    this._chart.options.scales.y.ticks.callback = (value) =>
      formatValue(metric, value)

    this._chart.update("active")
  }

  _updateActiveBtn(activeBtn) {
    this.btnTargets.forEach(btn => {
      btn.classList.remove("bg-(--color-brand)", "text-white", "font-semibold")
      btn.classList.add("text-(--color-text-muted)")
    })
    activeBtn.classList.add("bg-(--color-brand)", "text-white", "font-semibold")
    activeBtn.classList.remove("text-(--color-text-muted)")
  }
}
