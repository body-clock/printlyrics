# Stripe Checkout sells the two premium plans. All four values arrive from the
# environment, as this project's other deployment configuration does, and none of
# them is required for the application to boot: a host without them renders the
# songbook-saving page exactly as it reads today, with no purchase control and a
# checkout action that refuses.
#
# The secret key and the webhook signing secret are credentials. The two price
# IDs are identifiers for prices in the Stripe account, one per plan. A host that
# could take a payment but not verify the webhook that grants access would take
# money and grant nothing, so the whole feature is off unless all four are
# present; StripeGateway.configured? is the one place that decision lives.
# docs/rails_guidelines.md states the same contract for the application code.
Rails.application.config.x.stripe_secret_key = ENV["STRIPE_SECRET_KEY"].presence
Rails.application.config.x.stripe_webhook_secret = ENV["STRIPE_WEBHOOK_SECRET"].presence
Rails.application.config.x.stripe_price_monthly = ENV["STRIPE_PRICE_MONTHLY"].presence
Rails.application.config.x.stripe_price_day_pass = ENV["STRIPE_PRICE_DAY_PASS"].presence

# Say so at boot, naming what is missing and never a value.
if Rails.env.production?
  missing = {
    "STRIPE_SECRET_KEY" => Rails.application.config.x.stripe_secret_key,
    "STRIPE_WEBHOOK_SECRET" => Rails.application.config.x.stripe_webhook_secret,
    "STRIPE_PRICE_MONTHLY" => Rails.application.config.x.stripe_price_monthly,
    "STRIPE_PRICE_DAY_PASS" => Rails.application.config.x.stripe_price_day_pass
  }.select { |_, value| value.blank? }.keys

  if missing.any?
    Rails.logger.info(
      "Stripe is not fully configured (missing #{missing.join(', ')}): premium checkout is off, " \
      "the songbook-saving page renders the proposal wording, and no payment can be made."
    )
  end
end
