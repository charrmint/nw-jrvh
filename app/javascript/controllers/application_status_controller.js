import { Controller } from "@hotwired/stimulus"

// Keeps a status block fresh while an application is being processed (YMCA, Beyond Care, Parkcrest).
// Refetches the current page and swaps in the element marked data-application-status.
// The server only renders data-controller="application-status" while the status is pending/sending,
// so polling stops by itself once the application reaches a final state.
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 2000 } }

  connect() { this.scheduleRefresh() }

  disconnect() { window.clearTimeout(this.timeout) }

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

      const doc = new DOMParser().parseFromString(await response.text(), "text/html")
      const replacement = doc.querySelector("[data-application-status]")
      if (!replacement) throw new Error("Status block missing from response")

      this.element.replaceWith(replacement)
    } catch (error) {
      this.scheduleRefresh()
    }
  }
}
