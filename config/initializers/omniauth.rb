# Google is the first sign-in route, with email and password as the fallback.
#
# The values are read from the environment so a deployment can supply them
# without rewriting encrypted credentials. Credentials remain a fallback for a
# host that already keeps them there. A host with neither value renders no
# Google control and refuses the request phase outright, so nothing is implied
# that cannot happen.
Rails.application.config.x.google_client_id =
  ENV["GOOGLE_CLIENT_ID"].presence ||
    Rails.application.credentials.dig(:google, :client_id).presence
Rails.application.config.x.google_client_secret =
  ENV["GOOGLE_CLIENT_SECRET"].presence ||
    Rails.application.credentials.dig(:google, :client_secret).presence

if Rails.env.production?
  missing = {
    "GOOGLE_CLIENT_ID" => Rails.application.config.x.google_client_id,
    "GOOGLE_CLIENT_SECRET" => Rails.application.config.x.google_client_secret
  }.select { |_, value| value.blank? }.keys

  if missing.any?
    Rails.logger.info(
      "Google sign-in is not configured (missing #{missing.join(', ')}): " \
      "no Google control is rendered and no account can be linked."
    )
  end
end

# The request phase answers POST alone, and the CSRF protection middleware
# verifies the form's authenticity token before it runs. A host that cannot sign
# anyone in refuses the method, which leaves its unmounted routes to the router
# instead of sending anyone to Google with an empty client ID.
#
# `to_prepare` is used because the predicate is this application's own code and
# an initializer runs before it can be autoloaded. OmniAuth reads the value on
# every request, so setting it here changes nothing.
Rails.application.config.to_prepare do
  OmniAuth.config.allowed_request_methods = GoogleSignIn.configured? ? [ :post ] : []
end

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, nil, nil, {
    scope: "email,profile",
    # Show the chooser every time: a shared machine must not quietly sign the
    # last visitor back in.
    prompt: "select_account",
    access_type: "online",
    # Read the client per request rather than capturing it when the middleware is
    # built, so the strategy and the sign-in pages consult one value.
    setup: ->(env) do
      strategy = env["omniauth.strategy"]
      strategy.options.client_id = Rails.application.config.x.google_client_id
      strategy.options.client_secret = Rails.application.config.x.google_client_secret
    end
  }
end
