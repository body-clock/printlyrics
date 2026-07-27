require "test_helper"

class LyricsFlowTest < ActionDispatch::IntegrationTest
  test "landing page presents both entry paths and SEO metadata" do
    get root_path

    assert_response :success
    assert_select "h1", "PrintLyrics"
    assert_select "title", "PrintLyrics | Clean, printable lyrics"
    assert_select "meta[name='application-name'][content='PrintLyrics']", 1
    assert_select "form[action='#{lyrics_path}']", count: 2
    assert_select "turbo-frame#lyric_entry" do
      assert_select "form[data-turbo-frame='lyric_entry']", count: 1
    end
    assert_select "meta[name='description'][content*='printable lyric sheets']"
    assert_select "link[rel='canonical'][href='#{root_url}']"
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
          source_url: "https://genius.com/roy-harper-another-day-lyrics"
        }
      }
    end

    lyric = Lyric.last
    assert_redirected_to lyric_path(lyric)
    assert_equal "https://genius.com/roy-harper-another-day-lyrics", lyric.source_url
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
          source_url: "https://genius.com/artist-song-lyrics"
        }
      }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']", /Please paste your lyrics/
    assert_select "input[type='hidden'][name='lyric[source_url]'][value='https://genius.com/artist-song-lyrics']"
  end

  test "URL fetch pre-fills the editable form without persisting" do
    extraction = LyricExtractor::Extraction.new(
      title: "The Kiss",
      artist: "Judee Sill",
      lyrics: "[Verse]\nLove, rising from the mists"
    )
    extractor = Object.new
    extractor.define_singleton_method(:extract) { |_| extraction }

    assert_no_difference("Lyric.count") do
      with_extractor(extractor) do
        post lyrics_path, params: { fetch: "1", url: "https://genius.com/judee-sill-the-kiss-lyrics" }
      end
    end

    assert_response :success
    assert_select "[role='status']", /Lyrics fetched/
    assert_select "input[name='lyric[title]'][value='The Kiss']"
    assert_select "input[name='lyric[artist]'][value='Judee Sill']"
    assert_select "textarea[name='lyric[lyrics]']", /Love, rising/
    assert_select "input[type='hidden'][name='lyric[source_url]'][value='https://genius.com/judee-sill-the-kiss-lyrics']"
  end

  test "fetch errors return to the landing page with a useful message" do
    extractor = Object.new
    extractor.define_singleton_method(:extract) { |_| raise LyricExtractor::UnsupportedSiteError }

    with_extractor(extractor) do
      post lyrics_path, params: { fetch: "1", url: "https://example.com/song" }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_select "[role='alert']", /Couldn't fetch lyrics from that URL/
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

  def with_extractor(extractor)
    original_new = LyricExtractor.method(:new)
    LyricExtractor.define_singleton_method(:new) { extractor }
    yield
  ensure
    LyricExtractor.define_singleton_method(:new, original_new)
  end
end
