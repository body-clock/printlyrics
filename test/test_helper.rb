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

module GoogleConfiguration
  # The test environment's credentials may or may not hold a Google client,
  # depending on whose machine runs the suite. Every test starts from the host
  # that cannot sign anyone in; `with_google_configured` is how a test says
  # otherwise. The request phase follows the same predicate, as it does in the
  # initializer.
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
  # OmniAuth answers with this payload instead of calling Google, so the
  # middleware and the callback that run in production are the ones under test.
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

  # A callback that arrives carrying no payload at all.
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
    include GoogleConfiguration
    include GoogleAuthentication

    # Run tests in parallel with specified workers. Rails templates the worker
    # number onto the test database name and rebuilds each worker file from
    # db/schema.rb, so workers already have separate SQLite files under storage/
    # (gitignored, reused between runs). No parallelize_setup/teardown is needed.
    parallelize(workers: :number_of_processors)

    setup do
      Rails.configuration.x.google_client_id = nil
      Rails.configuration.x.google_client_secret = nil
      OmniAuth.config.allowed_request_methods = []
    end

    # The suite builds the records each test needs; test/fixtures holds no data
    # files, so fixtures are deliberately not loaded.
  end
end
