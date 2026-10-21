require "test_helper"

# Umami is the only analytics destination. The tracker is configured so every
# payload carries the redacted location the application builds, and so the
# dashboard's performance report has data to read.
class AnalyticsTest < ActionDispatch::IntegrationTest
  test "the Umami tracker renders from the origin the policy allows" do
    get root_path

    origin = URI(Rails.configuration.x.umami_origin).origin
    policy = response.headers["Content-Security-Policy"]

    assert_includes response.body, %(src="#{origin}/script.js")
    assert_includes response.body,
      %(data-website-id="#{Rails.configuration.x.umami_website_id}")
    # Umami fills url, title, and referrer from the document unless the payload
    # replaces them, and on a saved page the document carries the share token and
    # the song title. lib/analytics.js replaces all three on every event.
    assert_includes response.body, %(data-auto-track="false")
    assert_includes policy, "script-src 'self' #{origin} "
    assert_includes policy, "connect-src 'self' #{origin}"
  end

  test "no retired analytics tag or campaign allowlist remains" do
    get root_path

    assert_response :success
    refute_match(/plausible/i, response.body)
    refute_match(/plausible/i, response.headers["Content-Security-Policy"])
    refute_includes response.body, "data-analytics-campaigns"
    refute_match(/googletagmanager|google-analytics|gtag/, response.body)
    refute_match(/googletagmanager|google-analytics/, response.headers["Content-Security-Policy"])
  end

  test "no Umami tracker renders without a website ID" do
    previous = Rails.configuration.x.umami_website_id
    Rails.configuration.x.umami_website_id = nil

    get root_path

    assert_response :success
    refute_includes response.body, "data-website-id"
    refute_includes response.body, "analytics.printlyrics.app/script.js"
  ensure
    Rails.configuration.x.umami_website_id = previous
  end
end
