class IntegrationMappingVersion < ApplicationRecord
  validates :provider_key, :workflow_key, :step_key, :inventory_fingerprint, presence: true
  validates :version, numericality: { only_integer: true, greater_than: 0 }

  scope :current, -> { where(current: true) }

  def self.for_scope(provider_key:, workflow_key:, step_key:, external_location_id: nil, external_program_id: nil)
    where(
      provider_key: provider_key,
      workflow_key: workflow_key,
      step_key: step_key,
      external_location_id: external_location_id,
      external_program_id: external_program_id
    )
  end
end
