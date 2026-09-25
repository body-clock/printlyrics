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

if Rails.env.production? && Rails.application.config.x.turnstile_site_key.blank?
  Rails.logger.warn("TURNSTILE_SITE_KEY is not set: the feedback form has no bot gate.")
end
