class User < ApplicationRecord
  # Passwordless auth: Google OAuth + email OTP code.
  # We keep :database_authenticatable so Devise's session helpers (sign_in,
  # current_user, etc.) work, but `password_required?` is forced to false
  # so users without a password can be created via OTP / OAuth.
  devise :database_authenticatable, :registerable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  belongs_to :company, optional: true

  enum :role, { owner: "owner", admin: "admin", member: "member" }

  # ── Google OAuth ─────────────────────────────────────────────────────────
  # Looks up by provider/uid first, then falls back to email so a user that
  # previously signed up via OTP can link their Google account on first login.
  def self.from_google(auth)
    user = find_by(provider: auth.provider, uid: auth.uid) ||
           find_by(email: auth.info.email&.downcase) ||
           new(email: auth.info.email&.downcase)

    user.assign_attributes(
      provider:   auth.provider,
      uid:        auth.uid,
      name:       user.name.presence || auth.info.name,
      avatar_url: auth.info.image
    )
    user.save!(validate: user.new_record?) # email-format validation only matters on create
    user
  end

  # ── OTP (email-code) authentication ──────────────────────────────────────
  OTP_LENGTH           = 4
  OTP_EXPIRY           = 10.minutes
  OTP_MAX_ATTEMPTS     = 5
  OTP_RESEND_COOLDOWN  = 30.seconds

  # Generate a fresh 6-digit code, store its bcrypt digest, return the plain code.
  def generate_otp!
    code = SecureRandom.random_number(10**OTP_LENGTH).to_s.rjust(OTP_LENGTH, "0")
    update!(
      otp_digest:     ::BCrypt::Password.create(code),
      otp_sent_at:    Time.current,
      otp_expires_at: OTP_EXPIRY.from_now,
      otp_attempts:   0
    )
    code
  end

  # Verify a submitted code. Returns one of:
  #   :ok                 — code matches, OTP consumed
  #   :expired            — no code on file or window elapsed
  #   :too_many_attempts  — attempts exceeded, code revoked
  #   :invalid            — wrong code (attempts incremented)
  def verify_otp(code)
    return :expired           if otp_digest.blank? || otp_expires_at.blank? || otp_expires_at < Time.current
    return :too_many_attempts if otp_attempts >= OTP_MAX_ATTEMPTS

    if ::BCrypt::Password.new(otp_digest) == code.to_s
      clear_otp!
      :ok
    else
      increment!(:otp_attempts)
      otp_attempts >= OTP_MAX_ATTEMPTS ? :too_many_attempts : :invalid
    end
  end

  def clear_otp!
    update!(otp_digest: nil, otp_expires_at: nil, otp_sent_at: nil, otp_attempts: 0)
  end

  def otp_resend_available_in
    return 0 if otp_sent_at.blank?
    remaining = (otp_sent_at + OTP_RESEND_COOLDOWN - Time.current).to_i
    [remaining, 0].max
  end

  def can_resend_otp?
    otp_resend_available_in.zero?
  end

  private

  # Devise hook — passwords are never required since we use OTP/OAuth.
  def password_required?
    false
  end
end

