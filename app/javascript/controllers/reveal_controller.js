import { Controller } from "@hotwired/stimulus"

// Fades children in as they scroll into view. Mark items with data-reveal-item.
export default class extends Controller {
  connect() {
    const items = this.element.querySelectorAll("[data-reveal-item]")
    if (!("IntersectionObserver" in window)) return
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) { entry.target.classList.add("in"); this.observer.unobserve(entry.target) }
      })
    }, { threshold: 0.15 })
    items.forEach((el, i) => { el.classList.add("reveal"); el.style.setProperty("--d", `${i * 0.1}s`); this.observer.observe(el) })
  }

  disconnect() { this.observer?.disconnect() }
}
