class SignInToken < ApplicationRecord
  belongs_to :user

  TOKEN_EXPIRY = 15.minutes

  scope :active, -> { where("expires_at > ? AND used_at IS NULL", Time.current) }

  def self.generate!(user:)
    create!(
      user:       user,
      token:      SecureRandom.urlsafe_base64(24),
      expires_at: TOKEN_EXPIRY.from_now
    )
  end

  def consume!
    update!(used_at: Time.current)
  end

  def expired?
    expires_at <= Time.current || used_at.present?
  end
end
