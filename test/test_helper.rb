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
  # The test environment leaves the five Stripe values unset, which is the state
  # the unconfigured checks are written against. This is how a test says the host
  # can sell — including the signing secret a webhook payload is signed with.
  def with_stripe_configured(secret_key: "sk_test_probe", webhook_secret: "whsec_probe",
    monthly_price_id: "price_monthly_probe", annual_price_id: "price_annual_probe",
    day_pass_price_id: "price_day_pass_probe")
    previous = {
      stripe_secret_key: Rails.configuration.x.stripe_secret_key,
      stripe_webhook_secret: Rails.configuration.x.stripe_webhook_secret,
      stripe_price_monthly: Rails.configuration.x.stripe_price_monthly,
      stripe_price_annual: Rails.configuration.x.stripe_price_annual,
      stripe_price_day_pass: Rails.configuration.x.stripe_price_day_pass
    }
    Rails.configuration.x.stripe_secret_key = secret_key
    Rails.configuration.x.stripe_webhook_secret = webhook_secret
    Rails.configuration.x.stripe_price_monthly = monthly_price_id
    Rails.configuration.x.stripe_price_annual = annual_price_id
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

module GoogleConfiguration
  # The test environment's credentials hold no Google client, which is the state
  # the unconfigured checks are written against. This is how a test says the host
  # can sign someone in with Google — including the request phase, which a host
  # that cannot sign anyone in refuses outright.
  def with_google_configured(client_id: "google-client-probe", client_secret: "google-secret-probe")
    previous = {
      google_client_id: Rails.configuration.x.google_client_id,
      google_client_secret: Rails.configuration.x.google_client_secret,
      allowed_request_methods: OmniAuth.config.allowed_request_methods
    }
    Rails.configuration.x.google_client_id = client_id
    Rails.configuration.x.google_client_secret = client_secret
    OmniAuth.config.allowed_request_methods = [ :post ]
    yield
  ensure
    Rails.configuration.x.google_client_id = previous[:google_client_id]
    Rails.configuration.x.google_client_secret = previous[:google_client_secret]
    OmniAuth.config.allowed_request_methods = previous[:allowed_request_methods]
  end
end

module GoogleAuthentication
  # OmniAuth answers with this payload instead of calling Google, so the middleware
  # and the callback that run in production are the ones under test. The payload is
  # the shape the strategy builds: `info.email` is empty unless Google verified the
  # address, and the unverified one is named separately.
  def with_google_auth(uid: "google-uid-1", email: "person@example.test", email_verified: true,
    provider: "google_oauth2")
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid,
      info: {
        name: "Google Person",
        email: email_verified ? email : nil,
        unverified_email: email,
        email_verified: email_verified
      }
    )
    yield
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  # A callback that arrives carrying no payload at all, which is the shape this
  # action has to survive if the middleware ever hands it one.
  def with_no_google_payload
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    yield
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:google_oauth2] = nil
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
    include GoogleConfiguration
    include GoogleAuthentication

    # The Google sign-in's two values live in credentials, which the machine running
    # the suite may hold — a developer's does, a CI runner's does not. Every test
    # starts from the host that cannot sign anyone in, so an assertion about that
    # state does not depend on whose machine it ran on; `with_google_configured` is
    # how a test says otherwise.
    setup do
      Rails.configuration.x.google_client_id = nil
      Rails.configuration.x.google_client_secret = nil
      OmniAuth.config.allowed_request_methods = []
    end

    # Run tests in parallel with specified workers. Rails templates the worker
    # number onto the test database name and rebuilds each worker file from
    # db/schema.rb, so workers already have separate SQLite files under storage/
    # (gitignored, reused between runs). No parallelize_setup/teardown is needed.
    parallelize(workers: :number_of_processors)

    # The suite builds the records each test needs; test/fixtures holds no data
    # files, so fixtures are deliberately not loaded.
  end
end
