class PagesController < ApplicationController
  # Public landing page.
  allow_unauthenticated_access

  def welcome
    # `authenticated?` resumes the session from the cookie (public pages skip require_authentication).
    redirect_to home_path if authenticated?
  end
end
