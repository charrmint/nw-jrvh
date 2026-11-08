import { Controller } from "@hotwired/stimulus"

// Child birthdate: choose exactly one of "born", "due" or "unknown".
// Inputs for the unchosen options are disabled so they are not submitted,
// which satisfies the Child model's "choose exactly one" validation.
export default class extends Controller {
  static targets = ["born", "due", "estimated", "unknown"]
  static values = { kind: String }

  connect() { this.apply(this.kindValue || "born") }

  change(event) { this.apply(event.target.value) }

  apply(kind) {
    this.toggle(this.bornTarget, kind === "born", true)
    this.toggle(this.dueTarget, kind === "due", true)
    this.toggle(this.estimatedTarget, kind !== "unknown", false)
    this.unknownTarget.value = kind === "unknown" ? "1" : "0"
  }

  toggle(group, on, requireDates) {
    group.hidden = !on
    group.querySelectorAll("input").forEach((input) => {
      input.disabled = !on
      if (requireDates && input.type === "date") input.required = on
    })
  }
}
