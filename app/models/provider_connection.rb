class ProviderConnection < ApplicationRecord
  PROVIDER_KEYS = %w[ymca].freeze

  belongs_to :user
  attr_accessor :password

  validates :provider_key, inclusion: { in: PROVIDER_KEYS }
  validates :username, presence: true
  validates :encrypted_password, presence: true
  validate :password_required_for_new_connection

  before_validation :normalize_and_encrypt_password

  def decrypted_password
    encryptor.decrypt_and_verify(encrypted_password)
  end

  private
    def normalize_and_encrypt_password
      self.username = username.to_s.strip
      self.encrypted_password = encryptor.encrypt_and_sign(password) if password.present?
      self.password = nil
    end

    def password_required_for_new_connection
      errors.add(:password, "is required") if new_record? && encrypted_password.blank?
    end

    def encryptor
      key = Rails.application.key_generator.generate_key("onekare/provider-credentials/v1", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
end
