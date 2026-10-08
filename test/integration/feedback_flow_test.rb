require "test_helper"

class FeedbackFlowTest < ActionDispatch::IntegrationTest
  # Stands in for TurnstileClient: it records the token it was handed and
  # returns the outcome the test chose.
  class FakeTurnstileClient
    attr_reader :tokens, :remote_ips

    def initialize(outcome)
      @outcome = outcome
      @tokens = []
      @remote_ips = []
    end

    def verify(token, remote_ip: nil)
      @tokens << token
      @remote_ips << remote_ip
      raise @outcome if @outcome.is_a?(TurnstileClient::ServiceError)

      @outcome
    end
  end

  # Stands in for UmamiClient: it records what it was asked to report, and can be
  # told to refuse the way the service does.
  class FakeUmamiClient
    attr_reader :reports

    def initialize(outcome = :ok)
      @outcome = outcome
      @reports = []
    end

    def configured? = true

    def record_feedback(feedback, ip: nil, user_agent: nil, hostname: nil)
      raise @outcome if @outcome.is_a?(UmamiClient::ServiceError)

      @reports << { feedback: feedback, ip: ip, user_agent: user_agent, hostname: hostname }
    end
  end

  test "the page asks for the work, not for a rating" do
    get feedback_path

    assert_response :success
    assert_select "meta[name='robots'][content='noindex, nofollow']"
    assert_select "link[rel='canonical'][href='#{feedback_url}']"
    assert_select "form[action='#{feedback_path}'] textarea[name='feedback[message]']"
    assert_select "form[action='#{feedback_path}'] input[name='feedback[query]']"
    assert_select "form[action='#{feedback_path}'] input[name='feedback[contact_email]']"
  end

  test "the page offers the answers the submission can carry" do
    get feedback_path

    assert_select "select[name='feedback[reason]']" do
      Feedback::REASONS.each do |reason|
        assert_select "option[value='#{reason}']", text: I18n.t("feedbacks.reasons.#{reason}")
      end
      assert_select "option[value='']"
    end
    # The note is written here, so this is the page the submission reports.
    assert_select "form[action='#{feedback_path}'] input[name='feedback[surface]'][value='feedback_page']"
  end

  test "the sheet prompt's link lands with both answers already chosen" do
    get feedback_path(surface: "sheet", reason: "print_problem")

    assert_response :success
    assert_select "form[action='#{feedback_path}'] input[name='feedback[surface]'][value='sheet']"
    assert_select "select[name='feedback[reason]'] option[value='print_problem'][selected]"
  end

  test "a surface and an answer this application never offered fall back" do
    get feedback_path(surface: "newsletter", reason: "praise")

    assert_select "form[action='#{feedback_path}'] input[name='feedback[surface]'][value='feedback_page']"
    assert_select "select[name='feedback[reason]'] option[value='praise'][selected]", count: 0
  end

  test "the page is reachable from the shared resource navigation, without linking to itself" do
    get feedback_path

    assert_select "footer[data-resource-navigation] a[href='#{root_path}']", text: /print song lyrics/i
    assert_select "footer[data-resource-navigation] a[href='#{print_a_songbook_path}']", text: /songbook printing guide/i
    assert_select "footer[data-resource-navigation] a[href='#{feedback_path}']", count: 0
  end

  test "no widget renders while no site key is configured" do
    get feedback_path

    assert_select "div.turnstile", count: 0
    assert_select "script[src*='challenges.cloudflare.com']", count: 0
  end

  test "the widget and its script load once a site key is configured" do
    with_turnstile_site_key("1x00000000000000000000AA") do
      get feedback_path

      assert_select "div.turnstile[data-turnstile-site-key-value='1x00000000000000000000AA']"
      # The widget's action and the server's expectation are the same value; a
      # drift between them would reject every real submission.
      assert_select "div.turnstile[data-turnstile-action-value='#{TurnstileClient::ACTION}']"
      assert_select "script[src='https://challenges.cloudflare.com/turnstile/v0/api.js']"
    end
  end

  test "a verified submission is stored and the visitor is thanked" do
    client = verify_with(true) do
      post feedback_path, params: {
        feedback: { message: "Two columns, but I needed three.", surface: "feedback_page" },
        "cf-turnstile-response" => "token-from-widget"
      }
    end

    assert_redirected_to root_path
    feedback = Feedback.recent.first
    assert_equal "Two columns, but I needed three.", feedback.message
    assert_equal "feedback_page", feedback.surface
    assert feedback.verified
    assert_equal [ "token-from-widget" ], client.tokens
  end

  test "a rejected challenge keeps nothing and says so" do
    assert_no_difference("Feedback.count") do
      verify_with(false) do
        post feedback_path, params: { feedback: { message: "hello", surface: "feedback_page" } }
      end
    end

    assert_response :unprocessable_content
    assert_select ".flash-error", /didn't pass/
  end

  test "a challenge that cannot be judged stores nothing" do
    assert_no_difference("Feedback.count") do
      verify_with(TurnstileClient::ServiceError.new("siteverify unreachable")) do
        post feedback_path, params: { feedback: { message: "hello", surface: "feedback_page" } }
      end
    end

    assert_response :unprocessable_content
    assert_select ".flash-error", /didn't pass/
  end

  test "the visitor's address reaches the verifier" do
    client = verify_with(true) do
      post feedback_path, params: { feedback: { message: "hi", surface: "feedback_page" } }
    end

    assert_equal [ "127.0.0.1" ], client.remote_ips
  end

  test "an empty submission is refused without spending the challenge" do
    client = verify_with(true) do
      post feedback_path, params: { feedback: { message: "  ", surface: "feedback_page" } }
    end

    assert_response :unprocessable_content
    assert_select ".flash-error", /Add a note or a song title/
    assert_empty client.tokens
  end

  test "the search-miss prompt carries the song and its surface" do
    verify_with(true) do
      post feedback_path, params: { feedback: { query: "A song nobody has", surface: "search_miss" } }
    end

    feedback = Feedback.recent.first
    assert_equal "A song nobody has", feedback.query
    assert_equal "search_miss", feedback.surface
  end

  test "a surface this application never renders falls back to the feedback page" do
    verify_with(true) do
      post feedback_path, params: { feedback: { message: "hi", surface: "newsletter" } }
    end

    assert_equal "feedback_page", Feedback.recent.first.surface
  end

  test "a reply address is kept when the visitor gives one" do
    verify_with(true) do
      post feedback_path, params: {
        feedback: { message: "hi", contact_email: "singer@example.com", surface: "feedback_page" }
      }
    end

    assert_equal "singer@example.com", Feedback.recent.first.contact_email
  end

  test "a stored submission is reported to Umami with the visitor's own words" do
    sent = []
    with_umami_client(recording_umami_client(sent)) do
      verify_with(true) do
        post feedback_path,
          params: {
            feedback: { message: "Two columns, but I needed three.", query: "The Kiss", surface: "feedback_page" }
          },
          headers: { "User-Agent" => "Mozilla/5.0 (Windows NT 10.0)" }
      end
    end

    assert_equal 1, sent.size
    payload = sent.first[:body]["payload"]
    assert_equal "event", sent.first[:body]["type"]
    assert_equal UmamiClient::EVENT_NAME, payload["name"]
    assert_equal "/feedback", payload["url"]
    assert_equal "www.example.com", payload["hostname"]
    assert_equal({
      "feedback_surface" => "feedback_page",
      "song_query" => "The Kiss",
      "feedback_note" => "Two columns, but I needed three."
    }, payload["data"])

    # Umami hashes the address and the agent into the session id, so the
    # visitor's own pair is what files the event under the session their
    # pageviews opened rather than under this container's.
    assert_equal "127.0.0.1", payload["ip"]
    assert_equal "Mozilla/5.0 (Windows NT 10.0)", sent.first[:headers]["User-Agent"]
  end

  test "the search-miss prompt reports its surface's page, not the page it came from" do
    sent = []
    with_umami_client(recording_umami_client(sent)) do
      verify_with(true) do
        post feedback_path,
          params: { feedback: { query: "A song nobody has", surface: "search_miss" } },
          headers: { "Referer" => print_lyrics_on_one_page_url }
      end
    end

    assert_equal "/", sent.first[:body]["payload"]["url"]
    assert_equal({ "feedback_surface" => "search_miss", "song_query" => "A song nobody has" },
      sent.first[:body]["payload"]["data"])
  end

  test "the reply address stays in the table and out of the report" do
    sent = []
    with_umami_client(recording_umami_client(sent)) do
      verify_with(true) do
        post feedback_path, params: {
          feedback: { message: "hi", contact_email: "singer@example.com", surface: "feedback_page" }
        }
      end
    end

    assert_equal "singer@example.com", Feedback.recent.first.contact_email
    assert_not_includes sent.first[:body]["payload"]["data"].keys, "contact_email"
    assert_not_includes JSON.generate(sent.first[:body]), "singer@example.com"
  end

  test "the sheet a visit just generated asks about the print it made" do
    generate_sheet

    assert_select ".feedback-prompt[data-analytics-page-response='Feedback Prompt Shown']", 1
    assert_select ".feedback-prompt a[href='#{feedback_path(surface: 'sheet', reason: 'print_problem')}']",
      text: I18n.t("shared.feedback_prompt.action")
  end

  test "a sheet the visit came back to later does not ask again" do
    lyric = generate_sheet
    get lyric_path(lyric)

    assert_response :success
    assert_select ".feedback-prompt", count: 0
  end

  test "the print prompt's submission reports the sheet's shape, not its token, and the answer it arrived with" do
    sent = []
    with_umami_client(recording_umami_client(sent)) do
      generate_sheet
      verify_with(true) do
        post feedback_path, params: {
          feedback: { reason: "print_problem", message: "The second verse is cut off.", surface: "sheet" }
        }
      end
    end

    feedback = Feedback.recent.first
    assert_equal "sheet", feedback.surface
    assert_equal "print_problem", feedback.reason
    # What the visit had already made is the context the row is read with.
    assert_equal 1, feedback.visit_sheet_count

    payload = sent.first[:body]["payload"]
    assert_equal "/lyrics/:token", payload["url"]
    assert_equal({
      "feedback_surface" => "sheet",
      "feedback_note" => "The second verse is cut off.",
      "feedback_reason" => "print_problem"
    }, payload["data"])
    assert_not_includes JSON.generate(sent.first[:body]), Lyric.last.token
  end

  test "a submission from a visit that made nothing records no sheets" do
    verify_with(true) do
      post feedback_path, params: { feedback: { query: "A song nobody has", surface: "search_miss" } }
    end

    assert_equal 0, Feedback.recent.first.visit_sheet_count
  end

  test "an answer this application never offered is not stored" do
    verify_with(true) do
      post feedback_path, params: { feedback: { message: "hi", surface: "feedback_page", reason: "praise" } }
    end

    assert_nil Feedback.recent.first.reason
  end

  test "a rejected challenge reports nothing" do
    reported = report_with do
      verify_with(false) do
        post feedback_path, params: { feedback: { message: "hello", surface: "feedback_page" } }
      end
    end

    assert_empty reported.reports
  end

  test "a challenge that cannot be judged reports nothing" do
    reported = report_with do
      verify_with(TurnstileClient::ServiceError.new("siteverify unreachable")) do
        post feedback_path, params: { feedback: { message: "hello", surface: "feedback_page" } }
      end
    end

    assert_empty reported.reports
  end

  test "a service that refuses the report changes nothing the visitor sees" do
    reported = report_with(UmamiClient::ServiceError.new("Umami answered 503")) do
      verify_with(true) do
        post feedback_path, params: { feedback: { message: "hi", surface: "feedback_page" } }
      end
    end

    assert_redirected_to root_path
    assert_equal "hi", Feedback.recent.first.message
    assert_empty reported.reports
  end

  test "a host with no website to report to still stores and thanks the visitor" do
    # The real client, unconfigured: nothing is sent, and the form still works.
    with_umami_client(UmamiClient.new(website_id: "")) do
      verify_with(true) do
        post feedback_path, params: { feedback: { message: "hi", surface: "feedback_page" } }
      end
    end

    assert_redirected_to root_path
    assert_equal "hi", Feedback.recent.first.message
  end

  test "the visitor is returned to the page they wrote from" do
    verify_with(true) do
      post feedback_path,
        params: { feedback: { message: "hi", surface: "feedback_page" } },
        headers: { "Referer" => print_lyrics_on_one_page_url }
    end

    assert_redirected_to print_lyrics_on_one_page_url
  end

  test "an empty search offers the miss prompt with the query already in it" do
    client = Object.new
    client.define_singleton_method(:search) { |_| [] }

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "not a song" }
    end

    assert_response :success
    assert_select ".search-miss"
    assert_select ".search-miss input[name='feedback[query]'][value='not a song']"
    assert_select ".search-miss input[name='feedback[surface]'][value='search_miss']"
    assert_select ".search-miss form[action='#{feedback_path}']"
  end

  test "an empty search carries the query into the manual form" do
    client = Object.new
    client.define_singleton_method(:search) { |_| [] }

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "not a song" }
    end

    assert_response :success
    assert_select ".search-miss a[href='#lyric_lyrics']"
    assert_select "input[name='lyric[title]'][value='not a song']"
  end

  test "matches leave the miss prompt out" do
    result = LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214.0,
      plain_lyrics: "[Verse]\nLove, rising from the mists",
      synced_lyrics: nil,
      instrumental: false
    )
    client = Object.new
    client.define_singleton_method(:search) { |_| [ result ] }

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "judee sill the kiss" }
    end

    assert_response :success
    assert_select ".search-results form[action='#{select_lyrics_path}']"
    assert_select ".search-miss", count: 0
  end

  test "a search that fails does not offer the miss prompt" do
    client = Object.new
    client.define_singleton_method(:search) { |_| raise LrcLibClient::ServiceError }

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "judee sill" }
    end

    assert_response :service_unavailable
    assert_select ".search-miss", count: 0
  end

  private

  def verify_with(outcome)
    client = FakeTurnstileClient.new(outcome)
    with_turnstile_client(client) { yield }
    client
  end

  def report_with(outcome = :ok)
    client = FakeUmamiClient.new(outcome)
    with_umami_client(client) { yield }
    client
  end

  # The real client over a stubbed transport, so a test can read the payload
  # this application would put on the wire without reaching Umami.
  def recording_umami_client(sent)
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("#{Rails.configuration.x.umami_origin}#{UmamiClient::SEND_PATH}") do |env|
      sent << { body: JSON.parse(env.body), headers: env.request_headers }
      [ 200, { "Content-Type" => "application/json" }, "{}" ]
    end
    connection = Faraday.new { |faraday| faraday.adapter(:test, stubs) }

    UmamiClient.new(connection: connection, website_id: "ea5c0e32-fcc8-4081-814e-085e7dfefa20")
  end
end
