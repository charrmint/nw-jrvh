class MailboxConnection < ApplicationRecord
  GMAIL_SEND_SCOPE = "https://www.googleapis.com/auth/gmail.send"

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :encrypted_access_token, :encrypted_refresh_token, :access_token_expires_at, :connected_at, presence: true
  validates :scope, inclusion: { in: [ GMAIL_SEND_SCOPE ] }

  def access_token
    decrypt(encrypted_access_token)
  end

  def refresh_token
    decrypt(encrypted_refresh_token)
  end

  def access_token=(value)
    self.encrypted_access_token = encrypt(value)
  end

  def refresh_token=(value)
    self.encrypted_refresh_token = encrypt(value)
  end

  def access_token_expiring?
    access_token_expires_at <= 1.minute.from_now
  end

  private
    def encrypt(value)
      encryptor.encrypt_and_sign(value.to_s)
    end

    def decrypt(value)
      encryptor.decrypt_and_verify(value)
    end

    def encryptor
      key = Rails.application.key_generator.generate_key("onekare/gmail-oauth-tokens/v1", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm")
    end
end
