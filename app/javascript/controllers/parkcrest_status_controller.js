import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 1000 } }

  connect() {
    this.scheduleRefresh()
  }

  disconnect() {
    window.clearTimeout(this.timeout)
  }

  scheduleRefresh() {
    this.timeout = window.setTimeout(() => this.refresh(), this.intervalValue)
  }

  async refresh() {
    try {
      const response = await fetch(this.urlValue, {
        headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
        credentials: "same-origin",
        cache: "no-store"
      })
      if (!response.ok) throw new Error(`Status request failed: ${response.status}`)

      const document = new DOMParser().parseFromString(await response.text(), "text/html")
      const replacement = document.querySelector("[data-parkcrest-status]")
      if (!replacement) throw new Error("Status response is missing")

      this.element.replaceWith(replacement)
    } catch (error) {
      this.scheduleRefresh()
    }
  }
}
