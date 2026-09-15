ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers. Rails templates the worker
    # number onto the test database name and rebuilds each worker file from
    # db/schema.rb, so workers already have separate SQLite files under storage/
    # (gitignored, reused between runs). No parallelize_setup/teardown is needed.
    parallelize(workers: :number_of_processors)

    # The suite builds the records each test needs; test/fixtures holds no data
    # files, so fixtures are deliberately not loaded.
  end
end
