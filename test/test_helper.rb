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

module ActiveSupport
  class TestCase
    include LrcLibClientInjection
    include TurnstileClientInjection
    include TurnstileSiteKey

    # Run tests in parallel with specified workers. Rails templates the worker
    # number onto the test database name and rebuilds each worker file from
    # db/schema.rb, so workers already have separate SQLite files under storage/
    # (gitignored, reused between runs). No parallelize_setup/teardown is needed.
    parallelize(workers: :number_of_processors)

    # The suite builds the records each test needs; test/fixtures holds no data
    # files, so fixtures are deliberately not loaded.
  end
end
