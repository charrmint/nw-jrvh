# Renders one ProfileSchema field. Field names look like profile[<field.id>] (or
# profile[<section>][<index>][<field>] for repeatable person records).
module ProfileFormHelper
  def profile_field(field, name: "profile[#{field.id}]", value: nil)
    dom_id = name.gsub(/[^\w]+/, "_")
    attrs = { class: "field" }
    if field.show_if
      attrs[:hidden] = true
      attrs[:data] = { depends_on: field.show_if }
    end

    content_tag(:div, attrs) do
      safe_join([
        content_tag(:label, label_with_badge(field), for: dom_id, class: ([ :boolean, :multi_select ].include?(field.type) ? "label" : nil)),
        profile_control(field, name, dom_id, value),
        (content_tag(:div, field.hint, class: "hint") if field.hint)
      ].compact)
    end
  end

  private

  def label_with_badge(field)
    badge = field.sensitive ? content_tag(:span, "Sensitive", class: "badge sensitive", title: "Only shared with a daycare when required, and only after you approve.") : "".html_safe
    safe_join([ field.label, badge ])
  end

  def profile_control(field, name, dom_id, value)
    case field.type
    when :long_text, :list
      text_area_tag(name, value, id: dom_id)
    when :boolean
      content_tag(:div, class: "choices", data: { action: "change->conditional#update" }) do
        safe_join(%w[yes no].map { |v|
          content_tag(:label) { safe_join([ radio_button_tag(name, v, value.to_s == v, id: "#{dom_id}_#{v}"), v.capitalize ]) }
        })
      end
    when :single_select
      select_tag(name, options_for_select(field.options || [], value), prompt: "Choose…", id: dom_id)
    when :multi_select
      content_tag(:div, class: "choices") do
        safe_join((field.options || []).map { |o|
          content_tag(:label) { safe_join([ check_box_tag("#{name}[]", o, Array(value).include?(o), id: "#{dom_id}_#{o.parameterize}"), o ]) }
        })
      end
    when :document
      file_field_tag(name, multiple: true, id: dom_id)
    when :consent
      content_tag(:label, class: "choices") { safe_join([ check_box_tag(name, "yes", value == "yes", id: dom_id), "I give permission" ]) }
    when :date     then date_field_tag(name, value, id: dom_id)
    when :time     then time_field_tag(name, value, id: dom_id)
    when :integer  then number_field_tag(name, value, id: dom_id, min: 0)
    when :phone    then telephone_field_tag(name, value, id: dom_id)
    when :email    then email_field_tag(name, value, id: dom_id)
    when :address  then text_field_tag(name, value, id: dom_id, placeholder: "Street, city, province, postal code")
    else                text_field_tag(name, value, id: dom_id)
    end
  end
end
