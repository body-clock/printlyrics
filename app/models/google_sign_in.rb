# The account a Google sign-in resolves to.
#
# A returning visitor is found by the identity row — the uid Google sent —
# rather than by an address either side could have changed since. A verified
# address creates an account only when no account already uses it. An existing
# email account is not claimed by whoever controls the same Google address:
# without an email verification step, that would let someone who registered the
# address first keep a password to an account another person then signs into.
# Email accounts sign in with their password instead.
class GoogleSignIn
  class Refused < StandardError; end

  PROVIDER = "google_oauth2"

  # One predicate for the sign-in pages, the middleware, and this resolver, so a
  # control cannot render for a client the strategy does not hold.
  def self.configured?
    Rails.configuration.x.google_client_id.present? &&
      Rails.configuration.x.google_client_secret.present?
  end

  attr_reader :user

  def initialize(auth)
    @auth = auth
    @created = false
  end

  def call
    raise Refused, "Google sign-in is not configured" unless self.class.configured?
    raise Refused, "no Google payload arrived" if auth.blank?
    raise Refused, "the payload is not a Google one" unless provider == PROVIDER
    raise Refused, "no Google uid arrived" if uid.blank?

    identity = Identity.find_by(provider: PROVIDER, uid: uid)
    return identity.user if identity

    raise Refused, "Google did not verify the address" if email.blank?
    raise Refused, "an account already uses the address" if User.exists?(email_address: email)

    @user = create_user(email)
    link_identity
    user
  end

  def created? = @created

  private

  def auth
    @auth || {}
  end

  def provider
    auth["provider"].to_s
  end

  def uid
    auth["uid"].to_s.presence
  end

  # Nil unless Google verified the address: the strategy leaves `info.email`
  # empty for an unverified one and names `unverified_email` instead.
  def email
    info = auth["info"]
    return if info.blank? || !info["email_verified"]

    info["email"].to_s.strip.downcase.presence
  end

  # An account made this way has no password the visitor knows. The identity is
  # how they sign in, and the reset form is how they add a password.
  def create_user(email)
    @created = true
    User.create!(email_address: email, password: SecureRandom.hex(32))
  rescue ActiveRecord::RecordNotUnique
    # Another callback created the account first. This payload is a sign-in for
    # that account only if it also wrote the identity; it did not, so refuse
    # rather than link two arrivals that happened to share an address.
    @created = false
    raise Refused, "the address was claimed while this sign-in was in progress"
  rescue ActiveRecord::RecordInvalid
    @created = false
    raise Refused, "the address could not be stored"
  end

  def link_identity
    user.identities.create!(provider: PROVIDER, uid: uid)
  rescue ActiveRecord::RecordNotUnique
    @user = Identity.find_by!(provider: PROVIDER, uid: uid).user
  end
end
