# The account a Google sign-in resolves to.
#
# A returning visitor is found by the identity row — the uid Google sent — rather
# than by an address either side could have changed since. The address Google has
# verified is trusted once, for the first link: it claims the account that already
# uses it, which is how someone who signed up with a password adds Google later,
# and it creates the account when there is none. Anything less than a verified
# address is refused, because an unverified one says nothing about who controls
# it.
class GoogleSignIn
  # Raised for a payload that cannot become a sign-in. The caller answers it with
  # the sign-in page and a sentence rather than a stack trace.
  class Refused < StandardError; end

  PROVIDER = "google_oauth2"

  # Whether this host can complete a sign-in at all, which is the same predicate
  # the sign-in pages read before rendering a control and the middleware reads
  # before accepting the request phase. One definition, so the parts cannot drift.
  def self.configured?
    Rails.configuration.x.google_client_id.present? &&
      Rails.configuration.x.google_client_secret.present?
  end

  # Set by `call`, which is also what reports a new account to analytics: the same
  # event the password form reports, counted once.
  attr_reader :user

  def initialize(auth)
    @auth = auth
    @created = false
  end

  def call
    raise Refused, "this host is not configured to sign anyone in with Google" unless self.class.configured?
    raise Refused, "no Google payload arrived" if auth.blank?
    raise Refused, "the payload is not a Google one" unless provider == PROVIDER

    identity = Identity.find_by(provider: PROVIDER, uid: uid)
    return identity.user if identity

    raise Refused, "Google did not verify the address" if email.blank?

    @user = find_or_create_user(email)
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

  # Nil unless Google verified the address: the strategy leaves `info.email` empty
  # for an unverified one and names `unverified_email` instead, so this is the
  # value that says the visitor controls the address.
  def email
    info = auth["info"]
    return if info.blank? || !info["email_verified"]

    info["email"].to_s.strip.downcase.presence
  end

  def find_or_create_user(email)
    User.find_by(email_address: email) || create_user(email)
  rescue ActiveRecord::RecordNotUnique
    # Another callback created the account first: the unique index on the address
    # decided, and this sign-in is for the same account either way.
    User.find_by!(email_address: email)
  end

  # An account made this way has no password the visitor knows, and nothing here
  # pretends otherwise: the identity row is how they sign in, and the reset form
  # is how they add a password they choose.
  def create_user(email)
    @created = true
    User.create!(email_address: email, password: SecureRandom.hex(32))
  end

  def link_identity
    user.identities.create!(provider: PROVIDER, uid: uid)
  rescue ActiveRecord::RecordNotUnique
    @user = Identity.find_by!(provider: PROVIDER, uid: uid).user
  end
end
