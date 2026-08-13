require "test_helper"

class PrintingGuidesTest < ActionDispatch::IntegrationTest
  test "homepage clearly owns the song lyric printing intent" do
    get root_path

    assert_response :success
    assert_select "title", "Printable Song Lyrics - Find, Edit & Print | PrintLyrics"
    assert_select "meta[name='description'][content*='Find lyrics by song or artist']", 1
    assert_select "meta[name='description'][content*='save as PDF']", 1
    assert_select "h1", "Find, format, and print song lyrics"
    assert_select "main", /no copying from another lyrics site/i
    assert_select "main", /one or two columns/i
    assert_select "main", /save as PDF/i
    assert_select "section[aria-labelledby='why-printlyrics']", 1
    assert_select "section[aria-labelledby='common-questions'] details", minimum: 3

    structured_data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    application = structured_data.fetch("@graph").find { |node| node["@type"] == "WebApplication" }
    assert_equal true, application.fetch("isAccessibleForFree")
    assert_includes application.fetch("featureList"), "Search for lyrics by song title or artist"
    assert_includes application.fetch("featureList"), "Print or save as PDF"
  end

  test "one-page guide owns its intent and links into the tool" do
    get print_lyrics_on_one_page_path

    assert_response :success
    assert_select "title", "How to Print Song Lyrics on One Page | PrintLyrics"
    assert_select "meta[name='description'][content*='fit song lyrics on one page']", 1
    assert_select "meta[name='robots'][content*='index, follow']", 1
    assert_select "link[rel='canonical'][href='#{print_lyrics_on_one_page_url}']", 1
    assert_select "h1", "Print lyrics on one page"
    assert_select "a[href='#{root_path}']", text: /open the lyric printing tool/i
    assert_select "main", /font size/i
    assert_select "main", /two columns/i
    assert_select "main", /print preview/i
    assert_select "main", /headers and footers/i
    assert_select "main", /100%/i
    assert_select "section[aria-labelledby='one-page-questions'] details", minimum: 3
  end

  test "indexable pages link to each other with descriptive anchors" do
    get root_path

    assert_response :success
    assert_select ".tool-explainer", count: 1
    assert_select "[data-search-navigation]", count: 0
    assert_select "footer[data-resource-navigation]" do
      assert_select "a[href='#{print_lyrics_on_one_page_path}']", text: /one-page printing guide/i
      assert_select "a[href='#{songs_path}']", text: /browse printable songs/i
      assert_select "a[href='#{root_path}']", count: 0
    end

    get print_lyrics_on_one_page_path

    assert_response :success
    assert_select "[data-search-navigation]", count: 0
    assert_select "footer[data-resource-navigation]" do
      assert_select "a[href='#{root_path}']", text: /print song lyrics/i
      assert_select "a[href='#{songs_path}']", text: /browse printable songs/i
      assert_select "a[href='#{print_lyrics_on_one_page_path}']", count: 0
    end
  end

  test "generated lyric page omits search navigation" do
    lyric = Lyric.create!(lyrics: "Private line")

    get lyric_path(lyric)

    assert_response :success
    assert_select "[data-search-navigation]", count: 0
  end

  test "sitemap includes the homepage and one-page guide" do
    get sitemap_path(format: :xml)

    assert_response :success
    document = Nokogiri::XML(response.body)
    locations = document.xpath("//*[local-name()='loc']").map(&:text)
    assert_includes locations, root_url
    assert_includes locations, print_lyrics_on_one_page_url
  end
end
