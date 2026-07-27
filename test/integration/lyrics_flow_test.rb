require "test_helper"

class LyricsFlowTest < ActionDispatch::IntegrationTest
  test "landing page presents search and manual entry with SEO metadata" do
    get root_path

    assert_response :success
    assert_select "h1", "PrintLyrics"
    assert_select "title", "PrintLyrics | Clean, printable lyrics"
    assert_select "meta[name='application-name'][content='PrintLyrics']", 1
    assert_select "form[action='#{lyrics_path}']", count: 1
    assert_select "turbo-frame#lyric_entry" do
      assert_select "form[action='#{search_lyrics_path}'][data-turbo-frame='lyric_entry']", count: 1
    end
    assert_select "input[name='query'][placeholder*='Song title']"
    assert_select "meta[name='description'][content*='printable lyric sheets']"
    assert_select "link[rel='canonical'][href='#{root_url}']"
    assert_no_match(/Genius|AZLyrics|Song URL/, response.body)
  end

  test "collection URL redirects to the landing page" do
    get lyrics_path

    assert_redirected_to root_path
  end

  test "manual submission persists lyrics and redirects to its token URL" do
    assert_difference("Lyric.count", 1) do
      post lyrics_path, params: {
        lyric: {
          title: "Another Day",
          artist: "Roy Harper",
          lyrics: "The kettle's on\n\nThe sun has gone",
          source_url: "https://lrclib.net/api/get/123"
        }
      }
    end

    lyric = Lyric.last
    assert_redirected_to lyric_path(lyric)
    assert_equal "https://lrclib.net/api/get/123", lyric.source_url
  end

  test "manual submission accepts missing metadata" do
    post lyrics_path, params: { lyric: { title: "", artist: "", lyrics: "A lyric without a title" } }

    assert_redirected_to lyric_path(Lyric.last)
  end

  test "blank manual submission renders the form with an error" do
    assert_no_difference("Lyric.count") do
      post lyrics_path, params: {
        lyric: {
          title: "Untitled",
          artist: "",
          lyrics: " ",
          source_url: "https://lrclib.net/api/get/123"
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']", /Please paste your lyrics/
    assert_select "input[type='hidden'][name='lyric[source_url]'][value='https://lrclib.net/api/get/123']"
  end

  test "search returns selectable results without persisting lyrics" do
    result = LrcLibClient::Result.new(
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

    assert_no_difference("Lyric.count") do
      with_lrc_lib_client(client) do
        post search_lyrics_path, params: { query: "judee sill the kiss" }
      end
    end

    assert_response :success
    assert_select "[role='status']", /1 match/
    assert_select "form[action='#{select_lyrics_path}']" do
      assert_select "input[name='result_id'][value='42']"
      assert_select "button", /The Kiss/
      assert_select "button", /Judee Sill/
      assert_select "button", /Heart Food/
    end
  end

  test "selecting a result fills the editable form without persisting" do
    result = LrcLibClient::Result.new(
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
    client.define_singleton_method(:find) { |_| result }

    assert_no_difference("Lyric.count") do
      with_lrc_lib_client(client) do
        post select_lyrics_path, params: { result_id: "42", query: "judee sill the kiss" }
      end
    end

    assert_response :success
    assert_select "[role='status']", /Lyrics loaded/
    assert_select "input[name='lyric[title]'][value='The Kiss']"
    assert_select "input[name='lyric[artist]'][value='Judee Sill']"
    assert_select "textarea[name='lyric[lyrics]']", /Love, rising/
    assert_select "input[type='hidden'][name='lyric[source_url]'][value='https://lrclib.net/api/get/42']"
  end

  test "empty search and unavailable results render useful errors" do
    post search_lyrics_path, params: { query: " " }

    assert_response :unprocessable_content
    assert_select "[role='alert']", /Enter a song title or artist/

    client = Object.new
    client.define_singleton_method(:search) { |_| raise LrcLibClient::ServiceError }

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "the kiss" }
    end

    assert_response :service_unavailable
    assert_select "[role='alert']", /Song search is temporarily unavailable/
  end

  test "shareable page renders stanzas controls and structured metadata" do
    lyric = Lyric.create!(
      title: "Downtown Lights",
      artist: "The Blue Nile",
      lyrics: "[Verse]\nSometimes I walk away\n\n[Chorus]\nThe downtown lights"
    )

    get lyric_path(lyric)

    assert_response :success
    assert_select "h1", "Downtown Lights"
    assert_select ".stanza", count: 2
    assert_select "[data-preview-target='page']"
    assert_select "script[type='application/ld+json']", /MusicRecording/
    assert_select "link[rel='canonical'][href='#{lyric_url(lyric)}']"
    assert_select "meta[property='og:title'][content='Downtown Lights lyrics by The Blue Nile']"
    assert_select "meta[name='robots'][content='noindex, nofollow']", 1
  end

  test "visiting a shareable page renews its retention" do
    lyric = Lyric.create!(lyrics: "A line", expires_at: 1.day.from_now)

    get lyric_path(lyric)

    assert_in_delta 180.days.from_now, lyric.reload.expires_at, 1.second
  end

  test "expired lyric pages are unavailable" do
    lyric = Lyric.create!(lyrics: "A line", expires_at: 1.minute.ago)

    get lyric_path(lyric)

    assert_redirected_to root_path
  end

  test "unknown lyric tokens return to the form" do
    get lyric_path(token: "missing-token")

    assert_redirected_to root_path
    follow_redirect!
    assert_select "[role='alert']", /That lyric page expired or wasn't found/
  end

  test "sitemap does not publish saved shareable lyric pages" do
    lyric = Lyric.create!(lyrics: "A line")

    get sitemap_path(format: :xml)

    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_not_includes response.body, lyric_url(lyric)
    assert_includes response.body, root_url
  end

  private

  def with_lrc_lib_client(client)
    original_new = LrcLibClient.method(:new)
    LrcLibClient.define_singleton_method(:new) { client }
    yield
  ensure
    LrcLibClient.define_singleton_method(:new, original_new)
  end
end
