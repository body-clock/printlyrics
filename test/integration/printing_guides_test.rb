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
    # A contextual in-body link, not just the footer navigation.
    assert_select ".explainer-note a[href='#{print_lyrics_on_one_page_path}']",
      text: /one-page printing guide/i

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
    # A contextual in-body link carrying head-query anchor text.
    assert_select ".guide-answer a[href='#{root_path}']", text: /print your lyrics/i
    assert_select "main", /font size/i
    assert_select "main", /two columns/i
    assert_select "main", /print preview/i
    assert_select "main", /headers and footers/i
    assert_select "main", /100%/i
    assert_select "section[aria-labelledby='one-page-questions'] details", minimum: 3
  end

  test "guide structured data describes the steps the page actually renders" do
    get print_lyrics_on_one_page_path

    assert_response :success
    structured_data = JSON.parse(css_select("script[type='application/ld+json']").first.text)

    assert_equal "HowTo", structured_data.fetch("@type")
    assert_equal print_lyrics_on_one_page_url, structured_data.fetch("url")
    assert_equal "Print lyrics on one page", structured_data.fetch("name")

    steps = structured_data.fetch("step")
    assert_equal (1..5).to_a, steps.map { |step| step.fetch("position") }
    steps.each { |step| assert_equal "HowToStep", step.fetch("@type") }

    # Structured data must not drift from the visible instructions.
    assert_equal css_select(".guide-steps li").length, steps.length
    rendered = css_select(".guide-steps li h2").map(&:text)
    assert_equal rendered, steps.map { |step| step.fetch("name") }
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
