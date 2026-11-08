import { Controller } from "@hotwired/stimulus"

// Shows a field only when the yes/no question it depends on is answered "yes".
// Usage: data-controller="conditional" on the form; dependent fields carry data-depends-on="<field id>".
export default class extends Controller {
  connect() { this.update() }

  update() {
    this.element.querySelectorAll("[data-depends-on]").forEach((el) => {
      const name = `profile[${el.dataset.dependsOn}]`
      const checked = this.element.querySelector(`input[name="${CSS.escape(name)}"]:checked`)
      el.hidden = !(checked && checked.value === "yes")
    })
  }
}
