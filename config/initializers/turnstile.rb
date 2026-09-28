# Cloudflare Turnstile gates the feedback form. The site key and the accepted
# frontend hostnames are public — the site key is in the page source — so they
# arrive as environment variables from config/deploy.yml. The widget secret is a
# credential, like this project's other secrets: it lives in
# config/credentials.yml.enc under turnstile.secret_key, unlocked by
# RAILS_MASTER_KEY, which the deploy workflow supplies from the printlyrics-prod
# environment secret.
Rails.application.config.x.turnstile_site_key = ENV["TURNSTILE_SITE_KEY"].presence
Rails.application.config.x.turnstile_hostnames = ENV["TURNSTILE_HOSTNAMES"].presence
Rails.application.config.x.turnstile_secret_key =
  Rails.application.credentials.dig(:turnstile, :secret_key).presence

# The gate refuses anything it cannot confirm, so a host missing any of these
# refuses every submission rather than accepting them silently. Say so at boot,
# naming what is missing and never a value.
if Rails.env.production?
  missing = {
    "TURNSTILE_SITE_KEY" => Rails.application.config.x.turnstile_site_key,
    "TURNSTILE_HOSTNAMES" => Rails.application.config.x.turnstile_hostnames,
    "credentials turnstile.secret_key" => Rails.application.config.x.turnstile_secret_key
  }.select { |_, value| value.blank? }.keys

  if missing.any?
    Rails.logger.warn(
      "Turnstile is not fully configured (missing #{missing.join(', ')}): the feedback form refuses every submission."
    )
  end
end
