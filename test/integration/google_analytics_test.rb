require "test_helper"

class GoogleAnalyticsTest < ActionDispatch::IntegrationTest
  test "the GA4 tag renders beside Plausible and defers pageviews to the app" do
    get root_path

    assert_response :success
    assert_match(
      %r{<script async src="https://www\.googletagmanager\.com/gtag/js\?id=#{Rails.configuration.x.google_analytics_id}">},
      response.body
    )
    assert_includes response.body, "https://plausible.io/js/pa-"
    # lib/analytics.js redacts the location and title in the browser, so the tag
    # must not send a pageview of its own, and the signals that need consent stay
    # off.
    assert_includes response.body, "window.dataLayer = window.dataLayer || []"
    # The bootstrap is inline JavaScript, so ERB must not HTML-escape the
    # measurement ID: an escaped quote there is a syntax error that stops the tag
    # from configuring and loses every event.
    id = Rails.configuration.x.google_analytics_id
    assert_includes response.body, "window.gtag(\"config\", #{id.to_json}, {"
    refute_includes response.body, "&quot;#{id}&quot;"
    assert_includes response.body, "send_page_view: false"
    assert_includes response.body, "allow_google_signals: false"
    assert_includes response.body, "allow_ad_personalization_signals: false"
  end

  test "no Google tag renders without a measurement ID" do
    with_measurement_id(nil) do
      get root_path

      assert_response :success
      refute_match(/googletagmanager/, response.body)
      assert_includes response.body, "https://plausible.io/js/pa-"
    end
  end

  private

  def with_measurement_id(id)
    previous = Rails.configuration.x.google_analytics_id
    Rails.configuration.x.google_analytics_id = id
    yield
  ensure
    Rails.configuration.x.google_analytics_id = previous
  end
end
