import { Controller } from "@hotwired/stimulus"

// Dismissible flash message. Set data-flash-delay-value (ms) to auto-dismiss; 0 keeps it until closed.
export default class extends Controller {
  static values = { delay: { type: Number, default: 0 } }

  connect() {
    if (this.delayValue > 0) this.timer = setTimeout(() => this.close(), this.delayValue)
  }

  disconnect() { clearTimeout(this.timer) }

  close() {
    this.element.classList.add("leaving")
    setTimeout(() => this.element.remove(), 300)
  }
}
