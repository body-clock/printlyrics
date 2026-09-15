require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  # The public song catalog was removed, so the sitemap is deliberately tiny:
  # only the tool and the printing guide are offered to crawlers.
  test "publishes only the tool and the printing guide" do
    Song.create!(source_id: 101, title: "Private", artist: "Artist")
    lyric = Lyric.create!(lyrics: "Private lyric")

    get sitemap_path(format: :xml)

    assert_response :success
    document = Nokogiri::XML(response.body)
    locations = document.xpath("//*[local-name()='loc']").map(&:text)

    assert_equal [ root_url, print_lyrics_on_one_page_url ], locations
    assert_equal locations.uniq, locations
    refute_includes locations, lyric_url(lyric)
  end
end
