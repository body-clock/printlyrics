ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module LrcLibClientInjection
  # Replace the controller's source client with a fake for the duration of the
  # block, so higher-level tests never reach the network.
  def with_lrc_lib_client(client)
    previous = LyricsController.lrc_lib_client_factory
    LyricsController.lrc_lib_client_factory = -> { client }
    yield
  ensure
    LyricsController.lrc_lib_client_factory = previous
  end
end

module TurnstileClientInjection
  # Replace the controller's verifier for the duration of the block, so
  # higher-level tests never reach Cloudflare.
  def with_turnstile_client(client)
    previous = FeedbacksController.turnstile_client_factory
    FeedbacksController.turnstile_client_factory = -> { client }
    yield
  ensure
    FeedbacksController.turnstile_client_factory = previous
  end
end

module SheetGeneration
  # Makes a sheet the way the form does and loads it, which is what a visit
  # records: the generation is one-shot session state, and the page that follows
  # is where it is claimed. Two test files build visits, so it lives here.
  def generate_sheet(title: "A Song", lyrics: "A line to print")
    post lyrics_path, params: { lyric: { title: title, lyrics: lyrics } }
    follow_redirect!
    assert_response :success
    Lyric.last
  end
end

module UmamiClientInjection
  # Replace the controller's analytics sender for the duration of the block, so
  # higher-level tests never reach Umami.
  def with_umami_client(client)
    previous = FeedbacksController.umami_client_factory
    FeedbacksController.umami_client_factory = -> { client }
    yield
  ensure
    FeedbacksController.umami_client_factory = previous
  end
end

module TurnstileSiteKey
  # The widget renders only when a site key is configured. The test environment
  # leaves it unset, so no page loads Cloudflare's script by default.
  def with_turnstile_site_key(site_key)
    previous = Rails.configuration.x.turnstile_site_key
    Rails.configuration.x.turnstile_site_key = site_key
    yield
  ensure
    Rails.configuration.x.turnstile_site_key = previous
  end
end

module StripeGatewayInjection
  STRIPE_CONTROLLERS = [ PremiumCheckoutsController, StripeWebhooksController, BillingPortalsController ].freeze

  # Replace the Stripe client every controller reaches through for the duration
  # of the block, so no test calls Stripe.
  def with_stripe_gateway(gateway)
    previous = STRIPE_CONTROLLERS.map { |controller| [ controller, controller.stripe_gateway_factory ] }
    STRIPE_CONTROLLERS.each { |controller| controller.stripe_gateway_factory = -> { gateway } }
    yield
  ensure
    previous.each { |controller, factory| controller.stripe_gateway_factory = factory }
  end
end

module StripeConfiguration
  # The test environment leaves the four Stripe values unset, which is the state
  # the unconfigured checks are written against. This is how a test says the host
  # can sell — including the signing secret a webhook payload is signed with.
  def with_stripe_configured(secret_key: "sk_test_probe", webhook_secret: "whsec_probe",
    monthly_price_id: "price_monthly_probe", day_pass_price_id: "price_day_pass_probe")
    previous = {
      stripe_secret_key: Rails.configuration.x.stripe_secret_key,
      stripe_webhook_secret: Rails.configuration.x.stripe_webhook_secret,
      stripe_price_monthly: Rails.configuration.x.stripe_price_monthly,
      stripe_price_day_pass: Rails.configuration.x.stripe_price_day_pass
    }
    Rails.configuration.x.stripe_secret_key = secret_key
    Rails.configuration.x.stripe_webhook_secret = webhook_secret
    Rails.configuration.x.stripe_price_monthly = monthly_price_id
    Rails.configuration.x.stripe_price_day_pass = day_pass_price_id
    yield
  ensure
    previous.each { |name, value| Rails.configuration.x.public_send("#{name}=", value) }
  end
end

module StripeAnalyticsInjection
  # Replace the webhook's analytics sender for the duration of the block, so no
  # test reaches Umami either.
  def with_premium_analytics(client)
    previous = StripeWebhooksController.umami_client_factory
    StripeWebhooksController.umami_client_factory = -> { client }
    yield
  ensure
    StripeWebhooksController.umami_client_factory = previous
  end
end

module ActiveSupport
  class TestCase
    include LrcLibClientInjection
    include SheetGeneration
    include TurnstileClientInjection
    include UmamiClientInjection
    include TurnstileSiteKey
    include StripeGatewayInjection
    include StripeConfiguration
    include StripeAnalyticsInjection

    # Run tests in parallel with specified workers. Rails templates the worker
    # number onto the test database name and rebuilds each worker file from
    # db/schema.rb, so workers already have separate SQLite files under storage/
    # (gitignored, reused between runs). No parallelize_setup/teardown is needed.
    parallelize(workers: :number_of_processors)

    # The suite builds the records each test needs; test/fixtures holds no data
    # files, so fixtures are deliberately not loaded.
  end
end
