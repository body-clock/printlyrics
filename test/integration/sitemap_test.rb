require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  # The only crawlable pages are the tool, its printing guides, and the practical
  # songbook-saving page; private content is never included.

  test "publishes only the tool, its printing guides, and songbook saving page" do
    Song.create!(source_id: 101, title: "Private", artist: "Artist")
    lyric = Lyric.create!(lyrics: "Private lyric")

    get sitemap_path(format: :xml)

    assert_response :success
    document = Nokogiri::XML(response.body)
    locations = document.xpath("//*[local-name()='loc']").map(&:text)

    assert_equal(
      [ root_url, print_lyrics_on_one_page_url, print_a_songbook_url, save_songbooks_url ],
      locations
    )
    assert_equal locations.uniq, locations
    refute_includes locations, lyric_url(lyric)
  end
end
