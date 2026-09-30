# Be sure to restart your server when you modify this file.

# Content Security Policy for the app. Scripts are nonce-gated (importmap tags
# pick up the nonce automatically); analytics needs the Plausible origin and the
# Umami origin, which is one value (`config.x.umami_origin`) shared with the tag
# in the layout. Turnstile needs its API script and the widget's iframe, which is
# the two directives Cloudflare's CSP reference requires:
# https://developers.cloudflare.com/turnstile/reference/content-security-policy/
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, config.x.umami_origin, "https://plausible.io",
                       "https://challenges.cloudflare.com"
    policy.style_src   :self, :https
    # Umami collects on its own host, at the `/api/send` the tracker derives from
    # where its script was loaded.
    policy.connect_src :self, config.x.umami_origin, "https://plausible.io"
    # The Turnstile widget is an iframe served by Cloudflare.
    policy.frame_src   "https://challenges.cloudflare.com"
    policy.form_action :self
    policy.frame_ancestors :none
    policy.manifest_src :self
    # The preview controller sets `--preview-scale` on .paper-pages as an inline
    # style attribute, which a nonce (a script-only mechanism) cannot cover.
    policy.style_src_attr "'unsafe-inline'"
  end

  # A fresh nonce per request lets the inline analytics bootstrap run without
  # unsafe-inline. A session-derived nonce would be empty when a request never
  # touches the session (as in tests), so generate one directly.
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
