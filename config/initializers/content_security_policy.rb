# Be sure to restart your server when you modify this file.

# Content Security Policy for the app. Scripts are nonce-gated (importmap tags
# pick up the nonce automatically); analytics needs the Plausible origin and,
# during the dual run, the Google tag origin and its collection endpoints.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, "https://plausible.io", "https://www.googletagmanager.com"
    policy.style_src   :self, :https
    # GA4 sends its hits to region-specific hosts under both domains.
    policy.connect_src :self, "https://plausible.io", "https://www.google-analytics.com",
                       "https://*.google-analytics.com", "https://*.analytics.google.com"
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
