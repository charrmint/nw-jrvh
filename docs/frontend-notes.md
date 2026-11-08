# OneKare front end — drop-in notes

## Files (copy into the repo, same paths)
- `app/assets/stylesheets/application.css` — replaces the default stylesheet
- `app/views/layouts/application.html.erb` — replaces the layout (sidebar shows only when signed in)
- `app/views/{pages,home,kids,searches,daycare_applications,settings,shared}/…`
- `app/controllers/*_controller.rb` (new; does not touch ApplicationController)
- `app/helpers/onekare_helper.rb`, `app/helpers/profile_form_helper.rb`
- `app/models/profile_schema.rb` — the full question map, drives every profile form
- `app/models/demo_data.rb` — placeholder children/applications (Maya Chen from Figma); delete when real models exist
- `app/javascript/controllers/{conditional,repeater}_controller.js` — auto-registered by the existing Stimulus index
- `config/routes.snippet.rb` — lines to ADD to `config/routes.rb` (don't replace your auth routes)

## Auth wiring (needs confirmation)
I did not have `config/routes.rb`, the auth controllers, or the User model, so the UI finds your auth routes by trying common names in `OnekareHelper`:
- log in: `new_session_path`, `login_path`
- sign up: `new_registration_path`, `signup_path`, `new_user_path`
- sign out (DELETE): `session_path`, `logout_path`
- current user: `Current.user` or `current_user`

If your names differ, edit the three `*_target` methods and `onekare_user`. After login, your redirect to `root` hits the welcome page, which forwards signed-in users to `/home`.

## Not saved yet
Child profile forms post to `KidsController` and redirect with a “demo — not stored” notice. Field names are `profile[<field.id>]` (people sections: `profile[guardians][0][legal_first_name]`). Search and applications are layout only.

## Untested
Ruby was not available where this was written, so nothing has been run. Expect to fix small typos on first boot.
