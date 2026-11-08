import { Controller } from "@hotwired/stimulus"

// Repeatable person records (guardians, emergency contacts, authorized pickups, siblings).
export default class extends Controller {
  static targets = ["list", "template"]

  add() {
    const html = this.templateTarget.innerHTML.replaceAll("NEW_INDEX", Date.now())
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.target.closest("[data-repeater-item]").remove()
  }
}
