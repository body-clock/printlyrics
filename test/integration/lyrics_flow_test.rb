require "test_helper"

class LyricsFlowTest < ActionDispatch::IntegrationTest
  test "landing page presents search and manual entry with SEO metadata" do
    get root_path

    assert_response :success
    assert_select "h1", "PrintLyrics"
    assert_select "title", "Print Lyrics for Any Song | PrintLyrics"
    assert_select "meta[name='application-name'][content='PrintLyrics']", 1
    assert_select "meta[name='description'][content*='print lyrics for any song']"
    assert_select "meta[name='robots'][content*='index, follow']", 1
    assert_select "meta[property='og:site_name'][content='PrintLyrics']", 1
    assert_select "meta[property='og:image'][content='#{root_url}social-card.png']", 1
    assert_select "meta[name='twitter:card'][content='summary_large_image']", 1
    assert_select "link[rel='icon'][href='/favicon.svg'][sizes='any']", 1
    assert_select "link[rel='icon'][href='/favicon.ico'][sizes='48x48']", 1
    assert_select "link[rel='apple-touch-icon'][href='/apple-touch-icon.png']", 1
    assert_select "link[rel='manifest'][href='/site.webmanifest'][type='application/manifest+json']", 1
    assert_select "form[action='#{lyrics_path}']", count: 1
    assert_select "turbo-frame#lyric_entry" do
      assert_select "[data-controller='lyric-search']" do
        assert_select "form[action='#{search_lyrics_path}'][data-turbo-frame='lyric_entry'][aria-busy='false']", count: 1
        assert_select "button[type='submit']" do
          assert_select "[data-lyric-search-target='idleLabel']", text: "Search"
          assert_select "[data-lyric-search-target='busyLabel']", text: /Searching/
        end
      end
    end
    assert_select "input[name='query'][placeholder*='Song title']"
    assert_select "input[name='query'][aria-controls]", count: 0
    assert_select "input[name='query'][aria-expanded]", count: 0
    assert_select "link[rel='canonical'][href='#{root_url}']"
    assert_select "script[type='application/ld+json']", /WebSite/
    assert_select "script[type='application/ld+json']", /WebApplication/
    assert_select "script[type='application/ld+json']", /UtilitiesApplication/
    assert_select "script[type='application/ld+json']", /\"price\":\"0\"/
    assert_select ".intro p", /Print lyrics for any song/
    assert_select "main", /No account/
    assert_select "main", /musicians/i
    assert_select "main", /teachers/i
    assert_select "main", /personal/i
    assert_select "script", /autoCapturePageviews:\s*false/
    assert_select "form[action='#{search_lyrics_path}'][data-action*='lyric-search#start']", count: 1
    assert_no_match(/Genius|AZLyrics|Song URL/, response.body)
  end

  test "collection URL redirects to the landing page" do
    get lyrics_path

    assert_redirected_to root_path
  end

  test "manual submission persists lyrics without trusting a source URL" do
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
    assert_nil lyric.source_url
    assert_nil lyric.song
  end

  test "manual submission accepts missing metadata" do
    post lyrics_path, params: { lyric: { title: "", artist: "", lyrics: "A lyric without a title" } }

    assert_redirected_to lyric_path(Lyric.last)
  end

  test "blank manual submission renders the form with an error" do
    assert_no_difference([ "Lyric.count", "Song.count" ]) do
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
    assert_select "input[type='hidden'][name='lyric[source_url]']", count: 0
  end

  test "search returns selectable results without persisting lyrics" do
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

    assert_no_difference([ "Lyric.count", "Song.count" ]) do
      with_lrc_lib_client(client) do
        post search_lyrics_path, params: { query: "judee sill the kiss" }
      end
    end

    assert_response :success
    assert_select "section#song-search-results.search-results-panel[aria-label='Song search results']" do
      assert_select "[role='status']", /1 match/
      assert_select "button[type='button'][aria-label='Close search results']", count: 1
      assert_select "[role='list']", count: 1
    end
    assert_select "input[name='query'][aria-controls='song-search-results']"
    assert_select "form[action='#{select_lyrics_path}']" do
      assert_select "input[name='result_id'][value='42']"
      assert_select "input[id]", count: 0
      assert_select "button", /The Kiss/
      assert_select "button", /Judee Sill/
      assert_select "button", /Heart Food/
    end
  end

  test "selecting a result fills the editable form without persisting" do
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
    assert_select "input[type='hidden'][name='catalog_token']", count: 1
  end

  test "generating selected lyrics promotes the verified song" do
    result = LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: "Love, rising",
      synced_lyrics: nil,
      instrumental: false
    )

    assert_difference([ "Lyric.count", "Song.count" ], 1) do
      post lyrics_path, params: {
        catalog_token: SongCatalogToken.issue(result),
        lyric: {
          title: "My display title",
          artist: "My display artist",
          lyrics: "Love, rising",
          source_url: "https://attacker.example/forged"
        }
      }
    end

    lyric = Lyric.last
    assert_redirected_to lyric_path(lyric)
    assert_equal 42, lyric.song.source_id
    assert_equal "The Kiss", lyric.song.title
    assert_equal "My display title", lyric.title
    assert_equal "https://lrclib.net/api/get/42", lyric.source_url
  end

  test "invalid verified metadata returns the editable form without persistence" do
    result = LrcLibResult.new(
      id: 42,
      title: "T" * 201,
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: "Love, rising",
      synced_lyrics: nil,
      instrumental: false
    )

    assert_no_difference([ "Lyric.count", "Song.count" ]) do
      post lyrics_path, params: {
        catalog_token: SongCatalogToken.issue(result),
        lyric: { title: "Display title", artist: "Display artist", lyrics: "Love, rising" }
      }
    end

    assert_response :unprocessable_content
    assert_select "textarea[name='lyric[lyrics]']", /Love, rising/
  end

  test "selecting a removed song shows not-available message" do
    client = Object.new
    client.define_singleton_method(:find) { |_| raise LrcLibClient::NotFoundError }

    with_lrc_lib_client(client) do
      post select_lyrics_path, params: { result_id: "404", query: "the kiss" }
    end

    assert_response :unprocessable_content
    assert_select "#song-search-results [role='alert']", /That song is no longer available/
  end

  test "empty search and unavailable results render useful errors" do
    post search_lyrics_path, params: { query: " " }

    assert_response :unprocessable_content
    assert_select "#song-search-results [role='alert']", /Enter a song title or artist/

    client = Object.new
    client.define_singleton_method(:search) { |_| raise LrcLibClient::ServiceError }

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "the kiss" }
    end

    assert_response :service_unavailable
    assert_select "#song-search-results [role='alert']", /Song search is temporarily unavailable/
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
    assert_select "body[data-generated-page-key]", count: 0
    assert_select "button[data-action='preview#print']", count: 1
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
    LyricsController.alias_method :__original_lrc_lib_client, :lrc_lib_client
    LyricsController.define_method(:lrc_lib_client) { client }
    yield
  ensure
    LyricsController.alias_method :lrc_lib_client, :__original_lrc_lib_client
    LyricsController.remove_method :__original_lrc_lib_client
  end
end
