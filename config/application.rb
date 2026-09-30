require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Printlyrics
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # PrintLyrics has no image uploads or variants.
    config.active_storage.variant_processor = :disabled

    # Umami is the site's own analytics service, running in the accessories
    # beside the web container. It serves the tracker from this origin and
    # collects on it, and config/initializers/content_security_policy.rb allows
    # the same origin, so the two cannot drift; moving the service means editing
    # this line, `proxy.host` in config/deploy.yml, and DNS together.
    # docs/organic-search-operations.md owns the setup and the two-week parallel
    # run beside Plausible.
    config.x.umami_origin = "https://analytics.printlyrics.app"

    # Public by design — it is in the page source — and it belongs under
    # `env.clear` in config/deploy.yml, not in a secret. Umami generates it when
    # the site is added to the dashboard; a host without one renders no tracker.
    config.x.umami_website_id =
      ENV["UMAMI_WEBSITE_ID"] || ("00000000-0000-4000-8000-000000000000" if Rails.env.test?)
  end
end
