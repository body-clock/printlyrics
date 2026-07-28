require "test_helper"
require "rake"

class SongsRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("songs:verify_catalog")
    @task = Rake::Task["songs:verify_catalog"]
    @task.reenable
  end

  test "verifies a bounded catalog batch and reports the result" do
    received_limit = nil
    verifier = Object.new
    verifier.define_singleton_method(:verify) do |limit:|
      received_limit = limit
      { checked: 12, available: 8, unavailable: 3, failed: 1 }
    end

    output = with_limit("25") do
      with_replaced_constructor(SongCatalogVerifier, verifier) do
        capture_io { @task.invoke }.first
      end
    end

    assert_includes output, "checked=12"
    assert_includes output, "available=8"
    assert_includes output, "unavailable=3"
    assert_includes output, "failed=1"
    assert_equal 25, received_limit
  end

  test "fails loudly when the batch limit is invalid" do
    error = with_limit("many") do
      assert_raises(SystemExit) do
        capture_io { @task.invoke }
      end
    end

    assert_equal 1, error.status
  end

  private

  def with_replaced_constructor(klass, replacement)
    singleton = klass.singleton_class
    singleton.alias_method :original_new_for_songs_rake_test, :new
    singleton.define_method(:new) { |**| replacement }
    yield
  ensure
    singleton.alias_method :new, :original_new_for_songs_rake_test
    singleton.remove_method :original_new_for_songs_rake_test
  end

  def with_limit(value)
    previous = ENV["LIMIT"]
    ENV["LIMIT"] = value
    yield
  ensure
    ENV["LIMIT"] = previous
  end
end
