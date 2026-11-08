class Child < ApplicationRecord
  belongs_to :user

  normalizes :full_name, with: ->(name) { name.squish }

  validates :full_name, presence: true, length: { maximum: 100 }
  validates :date_of_birth, presence: true
end
