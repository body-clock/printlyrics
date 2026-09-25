# Cloudflare Turnstile gates the feedback form. The site key is public — it is
# in the page source — so it belongs in config/deploy.yml; the secret key is a
# credential and belongs in .kamal/secrets. Both arrive from the environment.
#
# A missing pair does not disable the form: TurnstileClient reports that it
# cannot judge a challenge, and the controller stores the submission unverified.
# That keeps a half-configured host, or a local one, from rejecting real
# visitors, and the warning below makes the unarmed gate visible.
Rails.application.config.x.turnstile_site_key = ENV["TURNSTILE_SITE_KEY"].presence
Rails.application.config.x.turnstile_secret_key = ENV["TURNSTILE_SECRET_KEY"].presence
# Frontend hostnames this deployment accepts tokens for, comma-separated. A
# production value never includes localhost or 127.0.0.1: the hostname in the
# siteverify reply is checked against this list.
Rails.application.config.x.turnstile_hostnames = ENV["TURNSTILE_HOSTNAMES"].presence

# The gate refuses anything it cannot confirm, so a deployment missing any of
# these refuses every submission rather than accepting them silently. Say so at
# boot, naming what is missing and never a value.
if Rails.env.production?
  missing = %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY TURNSTILE_HOSTNAMES].reject do |name|
    ENV[name].present?
  end
  if missing.any?
    Rails.logger.warn(
      "Turnstile is not fully configured (#{missing.join(', ')} unset): the feedback form refuses every submission."
    )
  end
end
