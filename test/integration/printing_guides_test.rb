require "test_helper"

class PrintingGuidesTest < ActionDispatch::IntegrationTest
  test "one-page guide owns its intent and links into the tool" do
    get print_lyrics_on_one_page_path

    assert_response :success
    assert_select "title", "Print Lyrics on One Page | PrintLyrics"
    assert_select "meta[name='description'][content*='fit song lyrics on one page']", 1
    assert_select "meta[name='robots'][content*='index, follow']", 1
    assert_select "link[rel='canonical'][href='#{print_lyrics_on_one_page_url}']", 1
    assert_select "h1", "Print lyrics on one page"
    assert_select "a[href='#{root_path}']", text: /open the lyric printing tool/i
    assert_select "main", /font size/i
    assert_select "main", /two columns/i
    assert_select "main", /print preview/i
  end

  test "indexable pages link to each other with descriptive anchors" do
    get root_path

    assert_response :success
    assert_select ".tool-explainer p:not(.eyebrow)", count: 1
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
