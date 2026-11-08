# OneKare front end v2 — what changed

This version is wired to the real `children` and `daycares` backend (from main) instead of demo data.

## Delete these old files from the repo (if you copied them earlier)
- `app/controllers/kids_controller.rb`, `app/controllers/searches_controller.rb`
- `app/views/kids/`, `app/views/searches/`
- `config/routes.snippet.rb`

## Real vs. placeholder
- Real: signup/login/logout, the logged-in user's children (name + date of birth), daycare search (name, city, postal code), daycare detail pages.
- Front end only: the profile question sections (answers are NOT stored), and the Applications list/details (sample rows from `app/models/demo_data.rb`).

## Needs from the backend
`User` must have `has_many :children` (ChildrenController already relies on it).
Profile question answers need a table; field ids in `ProfileSchema` are ready to map to columns.
