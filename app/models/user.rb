class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :full_name, with: ->(n) { n.squish }
  normalizes :phone_number, with: ->(p) { p.gsub(/\D/, "").sub(/\A1(?=\d{10}\z)/, "") }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :full_name, presence: true, length: { maximum: 100 }
  validates :phone_number, presence: true, format: { with: /\A\d{10}\z/, message: "must be a 10-digit local number" }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
