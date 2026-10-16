# The Google sign-in this application offers beside its own passwords.
#
# Both values are credentials, under `google` in config/credentials.yml.enc,
# unlocked by RAILS_MASTER_KEY: one Google client serves this application in every
# environment — both callbacks are registered on it — so there is one pair of
# values and one place they are read. The client ID is not a secret (it travels in
# the browser's URL to Google), but it is only ever read here rather than rendered
# into a page, so it does not need the route the Turnstile site key takes through
# config/deploy.yml.
Rails.application.config.x.google_client_id =
  Rails.application.credentials.dig(:google, :client_id).presence
Rails.application.config.x.google_client_secret =
  Rails.application.credentials.dig(:google, :client_secret).presence

# A host that cannot complete a sign-in renders no Google control and links no
# account, so nothing is implied that cannot happen. Say so at boot, naming what
# is missing and never a value.
if Rails.env.production?
  missing = {
    "credentials google.client_id" => Rails.application.config.x.google_client_id,
    "credentials google.client_secret" => Rails.application.config.x.google_client_secret
  }.select { |_, value| value.blank? }.keys

  if missing.any?
    Rails.logger.info(
      "Google sign-in is not configured (missing #{missing.join(', ')}): no Google control is rendered and no account can be linked."
    )
  end
end

# The request phase answers POST alone — that is OmniAuth's own default, and
# omniauth-rails_csrf_protection verifies the form's authenticity token before it
# runs, so no other page can start a sign-in with the visitor's cookie. A host
# that cannot sign anyone in refuses the method outright, which leaves its
# unmounted routes to the router rather than sending anyone to Google with an
# empty client ID.
#
# Set through `to_prepare`, because the predicate is this application's own code
# and an initializer runs before it can be autoloaded. OmniAuth reads the value on
# every request, so setting it there rather than at boot changes nothing.
Rails.application.config.to_prepare do
  OmniAuth.config.allowed_request_methods = GoogleSignIn.configured? ? [ :post ] : []
end

# The callback is Google's redirect back, and the code in it is exchanged for
# tokens here, on the server: what the middleware leaves in the request is a
# payload Google signed, which is why nothing downstream trusts the browser's
# word about who signed in.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, nil, nil, {
    scope: "email,profile",
    # The account chooser is shown every time: a shared machine must not quietly
    # sign the last visitor back in. Sign-in only, so no refresh token is asked
    # for or kept.
    prompt: "select_account",
    access_type: "online",
    # The client is read per request rather than captured when the middleware is
    # built, so this strategy and the predicate the sign-in pages read consult one
    # value: a control can never render for a client the strategy does not hold.
    setup: ->(env) do
      strategy = env["omniauth.strategy"]
      strategy.options.client_id = Rails.application.config.x.google_client_id
      strategy.options.client_secret = Rails.application.config.x.google_client_secret
    end
  }
end
