require "test_helper"

class FeedbackFlowTest < ActionDispatch::IntegrationTest
  # Stands in for TurnstileClient: it records the token it was handed and
  # returns the outcome the test chose.
  class FakeTurnstileClient
    attr_reader :tokens

    def initialize(outcome)
      @outcome = outcome
      @tokens = []
    end

    def verify(token)
      @tokens << token
      raise @outcome if @outcome.is_a?(TurnstileClient::ServiceError)

      @outcome
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

  test "a challenge that cannot be judged is stored unverified" do
    verify_with(TurnstileClient::ServiceError.new("siteverify unreachable")) do
      post feedback_path, params: { feedback: { message: "hello", surface: "feedback_page" } }
    end

    assert_redirected_to root_path
    assert_not Feedback.recent.first.verified
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
    assert_select ".search-miss", text: /Can't find the song/
    assert_select ".search-miss input[name='feedback[query]'][value='not a song']"
    assert_select ".search-miss input[name='feedback[surface]'][value='search_miss']"
    assert_select ".search-miss form[action='#{feedback_path}']"
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
end
