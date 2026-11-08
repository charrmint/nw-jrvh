# View helpers for the OneKare front end.
module OnekareHelper
  NAV_ITEMS = [
    { key: :home,         label: "Home",         path: :home_path,                  icon: :home },
    { key: :applications, label: "Applications", path: :daycare_applications_path,  icon: :clipboard },
    { key: :search,       label: "Search",       path: :daycares_path,              icon: :search },
    { key: :kids,         label: "Children",     path: :children_path,              icon: :face },
    { key: :settings,     label: "Settings",     path: :settings_path,              icon: :gear }
  ].freeze

  ICONS = {
    home:      '<path d="M3 11l9-8 9 8"/><path d="M5 10v10h14V10"/>',
    clipboard: '<rect x="6" y="4" width="12" height="17" rx="2"/><path d="M9 4h6v3H9z"/><path d="M9 12h6M9 16h4"/>',
    search:    '<circle cx="11" cy="11" r="7"/><path d="M21 21l-5-5"/>',
    face:      '<circle cx="12" cy="12" r="9"/><circle cx="9" cy="10" r=".6"/><circle cx="15" cy="10" r=".6"/><path d="M8.5 14.5c1 1.4 2.2 2 3.5 2s2.5-.6 3.5-2"/>',
    gear:      '<circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.1-1.2l2-1.5-2-3.4-2.3.9a7 7 0 0 0-2-1.2L14 3h-4l-.6 2.6a7 7 0 0 0-2 1.2l-2.3-.9-2 3.4 2 1.5A7 7 0 0 0 5 12c0 .4 0 .8.1 1.2l-2 1.5 2 3.4 2.3-.9a7 7 0 0 0 2 1.2L10 21h4l.6-2.6a7 7 0 0 0 2-1.2l2.3.9 2-3.4-2-1.5c.1-.4.1-.8.1-1.2z"/>'
  }.freeze

  def nav_icon(name)
    tag.svg(ICONS.fetch(name).html_safe, viewBox: "0 0 24 24", "aria-hidden": true)
  end

  # Highlights the sidebar button for the section the visitor is in.
  def nav_active?(key)
    case key
    when :home         then controller_name == "home"
    when :applications then controller_name == "daycare_applications"
    when :search       then controller_name == "daycares"
    when :kids         then %w[children profiles].include?(controller_name)
    when :settings     then controller_name == "settings"
    end
  end

  # ---- auth ---------------------------------------------------------------
  # Uses the app's Authentication concern (Current.session -> Current.user).
  def onekare_user
    Current.user
  end

  def signed_in?
    onekare_user.present?
  end

  def user_first_name
    onekare_user&.full_name.to_s.split.first
  end

  def user_initials
    onekare_user&.full_name.to_s.split.first(2).map { |p| p[0].upcase }.join.presence || "?"
  end

  def login_target  = login_path
  def signup_target = sign_up_path
  def logout_target = session_path

  def status_class(status)
    { "Missing information" => "missing", "Ready to review" => "ready", "In review" => "review" }.fetch(status, "review")
  end
end
