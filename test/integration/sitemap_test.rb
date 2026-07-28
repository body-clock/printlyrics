require "test_helper"

class SitemapTest < ActionDispatch::IntegrationTest
  test "publishes generic browse pagination and eligible song URLs only" do
    eligible = []
    51.times do |number|
      eligible << Song.create!(
        source_id: number + 1,
        title: "Song #{number}",
        artist: "Artist",
        indexable_at: 2.days.ago,
        last_verified_at: 1.day.ago
      )
    end
    unavailable = Song.create!(
      source_id: 100,
      title: "Gone",
      artist: "Artist",
      indexable_at: 2.days.ago,
      unavailable_at: 1.day.ago
    )
    private_song = Song.create!(source_id: 101, title: "Private", artist: "Artist")
    lyric = Lyric.create!(lyrics: "Private lyric")

    get sitemap_path(format: :xml)

    assert_response :success
    document = Nokogiri::XML(response.body)
    locations = document.xpath("//*[local-name()='loc']").map(&:text)
    assert_includes locations, root_url
    assert_includes locations, print_lyrics_on_one_page_url
    assert_includes locations, songs_url
    assert_includes locations, songs_url(page: 2)
    eligible.each { |song| assert_includes locations, song_url(song) }
    refute_includes locations, song_url(unavailable)
    refute_includes locations, song_url(private_song)
    refute_includes locations, lyric_url(lyric)
    assert_equal locations.uniq, locations
  end

  test "song lastmod reflects material updates" do
    song = Song.create!(
      source_id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      indexable_at: 2.days.ago,
      updated_at: 1.day.ago
    )

    get sitemap_path(format: :xml)

    document = Nokogiri::XML(response.body)
    node = document.xpath("//*[local-name()='url']").find do |url|
      url.at_xpath("./*[local-name()='loc']").text == song_url(song)
    end
    assert_equal song.updated_at.iso8601, node.at_xpath("./*[local-name()='lastmod']").text
  end
end
