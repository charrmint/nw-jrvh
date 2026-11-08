require "uri"

class GeneralApplication < ApplicationRecord
  CATEGORIES = %w[child_care_employee young_parent_program community_support_program transferring_care sibling_current sibling_alumni].freeze
  SCHEDULES = %w[any_available full_time part_time before_school after_school before_and_after_school].freeze
  SCHOOL_CATCHMENTS = %w[parkcrest aubrey cascade_or_inman other unknown].freeze

  ANSWER_KEYS = %w[
    preferred_start_date preferred_schedule
    school_name school_catchment support_required
    parent_first_name parent_last_name parent_email parent_phone parent_date_of_birth
    mailing_street mailing_city mailing_province mailing_postal_code mailing_country
    second_guardian_name second_guardian_email second_guardian_phone application_sms_consent
    affiliations_text affiliations_confirmed categories categories_confirmed
  ].freeze

  belongs_to :user
  belongs_to :child
  store_accessor :answers, *ANSWER_KEYS

  validates :child_id, uniqueness: { scope: :user_id }

  validates :parent_first_name, :parent_last_name,
    :parent_email, :parent_phone, :parent_date_of_birth, :mailing_street,
    :mailing_city, :mailing_province, :mailing_postal_code, :mailing_country,
    :preferred_start_date, presence: true
  validates :preferred_schedule, inclusion: { in: SCHEDULES }
  validates :support_required, inclusion: { in: %w[yes no] }
  validates :school_catchment, inclusion: { in: SCHOOL_CATCHMENTS }
  validates :affiliations_confirmed, :categories_confirmed, inclusion: { in: %w[1] }
  validates :parent_email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { parent_email.present? }
  validates :parent_phone, format: { with: /\A\d{10}\z/, message: "must be a 10-digit local number" }, if: -> { parent_phone.present? }
  validates :second_guardian_email, format: { with: URI::MailTo::EMAIL_REGEXP }, if: -> { second_guardian_email.present? }
  validate :child_belongs_to_user
  validate :answer_values

  before_validation :normalize_answers

  def school_age?
    child&.date_of_birth.present? && child.date_of_birth <= 4.years.ago.to_date
  end

  # The provider mapping layer consumes these stable field IDs, never form labels.
  def normalized_answers
    {
      "child.first_name" => child.first_name,
      "child.last_name" => child.last_name,
      "child.date_of_birth" => child.date_of_birth&.iso8601,
      "child.expected_due_date" => child.expected_due_date&.iso8601,
      "child.birthdate_unknown" => child.birthdate_unknown?,
      "child.birthdate_estimated" => child.birthdate_estimated?,
      "child.support_required" => support_required == "yes",
      "care.preferred_start_date" => preferred_start_date,
      "care.preferred_schedule" => preferred_schedule,
      "school.name" => school_name,
      "school.catchment" => school_catchment,
      "parent.first_name" => parent_first_name,
      "parent.last_name" => parent_last_name,
      "parent.email" => parent_email,
      "parent.local_phone" => parent_phone,
      "parent.date_of_birth" => parent_date_of_birth,
      "parent.mailing_street" => mailing_street,
      "parent.mailing_city" => mailing_city,
      "parent.mailing_province" => mailing_province,
      "parent.mailing_postal_code" => mailing_postal_code,
      "parent.mailing_country" => mailing_country,
      "parent.second_guardian_name" => second_guardian_name,
      "parent.second_guardian_email" => second_guardian_email,
      "parent.second_guardian_phone" => second_guardian_phone,
      "parent.application_sms_consent" => application_sms_consent == "1",
      "priority.affiliations" => affiliations_text,
      "priority.categories" => Array(categories)
    }.compact
  end

  private
    def child_belongs_to_user
      errors.add(:child, "must belong to your account") if child && user && child.user_id != user.id
      errors.add(:child, "needs a first and last name in the child profile") if child && (child.first_name.blank? || child.last_name.blank?)
    end

    def answer_values
      %w[preferred_start_date parent_date_of_birth].each do |key|
        next if public_send(key).blank?

        begin
          Date.iso8601(public_send(key))
        rescue Date::Error
          errors.add(key, "is invalid")
        end
      end
      errors.add(:categories, "contains an unknown choice") unless Array(categories).all? { |value| CATEGORIES.include?(value) }
      errors.add(:school_name, "is required for school-age children") if school_age? && school_name.blank?
    end

    def normalize_answers
      self.parent_email = parent_email.to_s.strip.downcase
      self.parent_phone = parent_phone.to_s.gsub(/\D/, "").sub(/\A1(?=\d{10}\z)/, "")
      self.second_guardian_email = second_guardian_email.to_s.strip.downcase
      self.second_guardian_phone = second_guardian_phone.to_s.gsub(/\D/, "")
      self.categories = Array(categories).reject(&:blank?).uniq
      %w[parent_first_name parent_last_name mailing_street mailing_city mailing_province mailing_postal_code mailing_country school_name second_guardian_name affiliations_text].each do |key|
        public_send("#{key}=", public_send(key).to_s.squish)
      end
      self.mailing_postal_code = mailing_postal_code.upcase
    end
end
