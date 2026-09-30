require "test_helper"

# The layout renders two trackers while the parallel run lasts. Each one has a
# flag that keeps its own automatic capture from reporting a saved page's
# location, and every flag is asserted here so a snippet edit cannot drop one
# silently.
class AnalyticsTest < ActionDispatch::IntegrationTest
  test "the Plausible snippet disables every automatic capture" do
    get root_path

    assert_response :success
    assert_includes response.body, "https://plausible.io/js/pa-"
    # Plausible's own capture sends the live location, which bypasses the token
    # redaction in lib/analytics.js, so a Form: Submission, File Download, or
    # Outbound Link event on a saved page carries a real share token. The site
    # settings cannot be relied on to keep them off.
    assert_includes response.body, "autoCapturePageviews: false"
    assert_includes response.body, "formSubmissions: false"
    assert_includes response.body, "fileDownloads: false"
    assert_includes response.body, "outboundLinks: false"
  end

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
    assert_includes policy, "connect-src 'self' #{origin} "
  end

  test "no Google tag or collection host survives the migration" do
    get root_path

    assert_response :success
    refute_match(/googletagmanager|google-analytics|gtag/, response.body)
    refute_match(/googletagmanager|google-analytics/, response.headers["Content-Security-Policy"])
  end

  test "no Umami tracker renders without a website ID" do
    previous = Rails.configuration.x.umami_website_id
    Rails.configuration.x.umami_website_id = nil

    get root_path

    assert_response :success
    refute_includes response.body, "data-website-id"
    assert_includes response.body, "https://plausible.io/js/pa-"
  ensure
    Rails.configuration.x.umami_website_id = previous
  end
end
