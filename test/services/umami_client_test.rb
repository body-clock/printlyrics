require "test_helper"

class UmamiClientTest < ActiveSupport::TestCase
  ORIGIN = "https://analytics.example.com"
  SITE_ID = "ea5c0e32-fcc8-4081-814e-085e7dfefa20"
  SEND_URL = "#{ORIGIN}#{UmamiClient::SEND_PATH}"

  test "reports a submission to the configured website as an event on its surface's page" do
    sent = nil
    headers = nil
    client = client_with do |stubs|
      stubs.post(SEND_URL) do |env|
        headers = env.request_headers
        sent = JSON.parse(env.body)
        [ 200, json_headers, "{}" ]
      end
    end

    feedback = Feedback.new(surface: "search_miss", query: "Marroon 5")
    client.record_feedback(feedback, ip: "203.0.113.7", user_agent: "Mozilla/5.0 (Windows NT 10.0)", hostname: "printlyrics.app")

    assert_equal "event", sent["type"]
    assert_equal SITE_ID, sent.dig("payload", "website")
    assert_equal UmamiClient::EVENT_NAME, sent.dig("payload", "name")
    assert_equal "/", sent.dig("payload", "url")
    assert_equal "printlyrics.app", sent.dig("payload", "hostname")

    # Umami hashes the address and the user agent into the session id, so the
    # visitor's own pair is what files the event under the session their
    # pageviews already opened rather than under this container's.
    assert_equal "203.0.113.7", sent.dig("payload", "ip")
    assert_equal "Mozilla/5.0 (Windows NT 10.0)", headers["User-Agent"]
    assert_equal "application/json", headers["Content-Type"]
  end

  test "carries the visitor's own words as the event's properties" do
    sent = nil
    client = client_with do |stubs|
      stubs.post(SEND_URL) do |env|
        sent = JSON.parse(env.body)
        [ 200, json_headers, "{}" ]
      end
    end

    feedback = Feedback.new(
      surface: "feedback_page",
      query: "The Kiss",
      message: "Two columns, but I needed three."
    )
    client.record_feedback(feedback)

    assert_equal({
      "feedback_surface" => "feedback_page",
      "song_query" => "The Kiss",
      "feedback_note" => "Two columns, but I needed three."
    }, sent.dig("payload", "data"))
    assert_equal "/feedback", sent.dig("payload", "url")
  end

  test "leaves the half a submission does not have out of the properties" do
    sent = nil
    client = client_with do |stubs|
      stubs.post(SEND_URL) do |env|
        sent = JSON.parse(env.body)
        [ 200, json_headers, "{}" ]
      end
    end

    client.record_feedback(Feedback.new(surface: "search_miss", query: "A song nobody has"))

    assert_equal({
      "feedback_surface" => "search_miss",
      "song_query" => "A song nobody has"
    }, sent.dig("payload", "data"))
  end

  test "never carries the reply address the visitor opted into" do
    body = nil
    client = client_with do |stubs|
      stubs.post(SEND_URL) do |env|
        body = env.body
        [ 200, json_headers, "{}" ]
      end
    end

    client.record_feedback(
      Feedback.new(surface: "feedback_page", message: "hi", contact_email: "singer@example.com")
    )

    assert_not_includes JSON.parse(body).dig("payload", "data").keys, "contact_email"
    assert_not_includes body, "singer@example.com"
  end

  test "every surface the model renders has a page to report" do
    missing = Feedback::SURFACES - UmamiClient::SURFACE_PATHS.keys

    assert_empty missing, "a new surface would be reported as the feedback page without a path here"
  end

  test "raises when the service answers with an error status" do
    client = client_with do |stubs|
      stubs.post(SEND_URL) { [ 503, json_headers, "" ] }
    end

    error = assert_raises(UmamiClient::ServiceError) do
      client.record_feedback(Feedback.new(surface: "feedback_page", message: "hi"))
    end
    assert_match(/503/, error.message)
  end

  test "raises when Umami is unreachable" do
    client = client_with do |stubs|
      stubs.post(SEND_URL) { raise Faraday::ConnectionFailed, "timed out" }
    end

    assert_raises(UmamiClient::ServiceError) do
      client.record_feedback(Feedback.new(surface: "feedback_page", message: "hi"))
    end
  end

  test "raises when this host has no website to report to, without asking the service" do
    client = UmamiClient.new(connection: unreachable_connection, website_id: "")

    assert_raises(UmamiClient::ServiceError) do
      client.record_feedback(Feedback.new(surface: "feedback_page", message: "hi"))
    end
  end

  test "treats the test environment's placeholder as no website at all" do
    client = UmamiClient.new(website_id: Rails.configuration.x.umami_placeholder_website_id)

    assert_not client.configured?
  end

  test "is configured by a real website id" do
    assert UmamiClient.new(website_id: SITE_ID).configured?
  end

  private

  def client_with(website_id: SITE_ID, origin: ORIGIN)
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs if block_given?
    connection = Faraday.new { |faraday| faraday.adapter(:test, stubs) }

    UmamiClient.new(connection: connection, origin: origin, website_id: website_id)
  end

  # A connection that raises if anything is ever sent through it.
  def unreachable_connection
    Faraday.new do |faraday|
      faraday.adapter(:test, Faraday::Adapter::Test::Stubs.new)
    end
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
