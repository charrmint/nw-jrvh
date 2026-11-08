# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_08_040000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "children", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "full_name", null: false
    t.date "date_of_birth", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_children_on_user_id"
  end

  create_table "daycares", force: :cascade do |t|
    t.string "source_facility_id", null: false
    t.string "name", null: false
    t.string "address"
    t.string "city", null: false
    t.string "postal_code", null: false
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.string "website_url"
    t.string "application_url"
    t.string "application_email"
    t.string "phone"
    t.jsonb "care_types", default: [], null: false
    t.jsonb "services", default: {}, null: false
    t.jsonb "reported_vacancies", default: {}, null: false
    t.datetime "vacancy_updated_at"
    t.string "application_type", default: "external", null: false
    t.string "support_status", default: "unconfigured", null: false
    t.jsonb "integration_settings", default: {}, null: false
    t.integer "integration_version"
    t.datetime "mapping_updated_at"
    t.text "mapping_failure_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_type"], name: "index_daycares_on_application_type"
    t.index ["city"], name: "index_daycares_on_city"
    t.index ["postal_code"], name: "index_daycares_on_postal_code"
    t.index ["source_facility_id"], name: "index_daycares_on_source_facility_id", unique: true
    t.index ["support_status"], name: "index_daycares_on_support_status"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "full_name", null: false
    t.string "phone_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "children", "users"
  add_foreign_key "sessions", "users"
end
