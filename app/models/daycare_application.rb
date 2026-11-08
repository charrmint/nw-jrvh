class DaycareApplication < ApplicationRecord
  STATUSES = %w[submitted].freeze

  belongs_to :child
  belongs_to :daycare

  validates :status, inclusion: { in: STATUSES }
  validates :submitted_at, presence: true
  validates :child_id, uniqueness: { scope: :daycare_id }
end
