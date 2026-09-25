require "test_helper"

class TurnstileClientTest < ActiveSupport::TestCase
  DUMMY_TOKEN = "XXXX.DUMMY.TOKEN.XXXX"

  test "accepts a token Cloudflare confirms for this action and hostname" do
    sent = nil
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) do |env|
        sent = Rack::Utils.parse_nested_query(env.body)
        [ 200, json_headers, success_body ]
      end
    end

    assert client.verify(DUMMY_TOKEN, remote_ip: "203.0.113.7")
    assert_equal({
      "secret" => "secret-key",
      "response" => DUMMY_TOKEN,
      "remoteip" => "203.0.113.7"
    }, sent)
  end

  test "accepts any hostname the deployment claims" do
    client = client_with(hostnames: "localhost, printlyrics.app") do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { [ 200, json_headers, success_body ] }
    end

    assert client.verify(DUMMY_TOKEN)
  end

  test "leaves remoteip out when the caller has no address for the visitor" do
    sent = nil
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) do |env|
        sent = Rack::Utils.parse_nested_query(env.body)
        [ 200, json_headers, success_body ]
      end
    end

    assert client.verify(DUMMY_TOKEN)
    assert_not sent.key?("remoteip")
  end

  test "rejects a token minted for another action" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { [ 200, json_headers, success_body(action: "signup") ] }
    end

    assert_not client.verify(DUMMY_TOKEN)
  end

  test "rejects a token minted for another hostname" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { [ 200, json_headers, success_body(hostname: "elsewhere.example") ] }
    end

    assert_not client.verify(DUMMY_TOKEN)
  end

  test "rejects a token Cloudflare declines" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) do
        [ 200, json_headers, '{"success":false,"error-codes":["invalid-input-response"]}' ]
      end
    end

    assert_not client.verify(DUMMY_TOKEN)
  end

  test "rejects a blank token without asking Cloudflare" do
    # Any request here would raise: the stubs are empty.
    client = client_with

    assert_not client.verify("")
    assert_not client.verify(nil)
  end

  test "rejects a token longer than the documented maximum without asking" do
    client = client_with

    assert_not client.verify("x" * (TurnstileClient::TOKEN_MAX_LENGTH + 1))
  end

  test "raises when neither key is configured" do
    client = client_with(site_key: "", secret_key: "")

    error = assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
    assert_match(/keys are not configured/, error.message)
  end

  test "raises when only the site key is configured" do
    client = client_with(site_key: "site-key", secret_key: "")

    assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
  end

  test "raises when no hostname is configured, without asking Cloudflare" do
    client = client_with(hostnames: "")

    error = assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
    assert_match(/hostnames are not configured/, error.message)
  end

  test "raises when Cloudflare is unreachable" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { raise Faraday::ConnectionFailed, "timed out" }
    end

    assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
  end

  test "raises when siteverify answers with an error status" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { [ 503, json_headers, "" ] }
    end

    error = assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
    assert_match(/503/, error.message)
  end

  test "raises when the reply is not JSON" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { [ 200, json_headers, "not json" ] }
    end

    assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
  end

  test "raises when the reply is JSON but not an object" do
    client = client_with do |stubs|
      stubs.post(TurnstileClient::VERIFY_URL) { [ 200, json_headers, "[]" ] }
    end

    assert_raises(TurnstileClient::ServiceError) { client.verify(DUMMY_TOKEN) }
  end

  private

  def client_with(site_key: "site-key", secret_key: "secret-key", hostnames: "printlyrics.app")
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs if block_given?
    connection = Faraday.new { |faraday| faraday.adapter(:test, stubs) }

    TurnstileClient.new(
      connection: connection,
      site_key: site_key,
      secret_key: secret_key,
      hostnames: hostnames
    )
  end

  def success_body(action: TurnstileClient::ACTION, hostname: "printlyrics.app")
    { success: true, action: action, hostname: hostname }.to_json
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end
end
