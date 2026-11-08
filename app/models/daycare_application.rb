class DaycareApplication < ApplicationRecord
  STATUSES = %w[pending sending submitted submission_failed submission_uncertain waitlist_request_sent send_failed send_uncertain].freeze

  belongs_to :child
  belongs_to :daycare

  validates :status, inclusion: { in: STATUSES }
  validates :submitted_at, presence: true, if: -> { status == "submitted" }
  validates :sent_at, presence: true, if: -> { status == "waitlist_request_sent" }
  validates :child_id, uniqueness: { scope: :daycare_id }
  validates :apply_request_id, uniqueness: true, allow_nil: true
end
