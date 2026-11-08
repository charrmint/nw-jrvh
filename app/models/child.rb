class Child < ApplicationRecord
  belongs_to :user
  has_one :general_application, dependent: :destroy
  has_many :daycare_applications, dependent: :restrict_with_error

  normalizes :full_name, with: ->(name) { name.squish }
  normalizes :first_name, :last_name, with: ->(name) { name.squish }

  before_validation :set_full_name

  validates :first_name, :last_name, presence: true, length: { maximum: 100 }
  validates :full_name, presence: true, length: { maximum: 100 }
  validate :birthdate_or_due_date

  private
    def set_full_name
      self.full_name = [ first_name, last_name ].join(" ") if first_name.present? && last_name.present?
    end

    def birthdate_or_due_date
      count = [ date_of_birth.present?, expected_due_date.present?, birthdate_unknown? ].count(true)
      return if count == 1

      errors.add(:base, "Choose exactly one: birthdate, expected due date, or unknown birthdate")
    end
end
