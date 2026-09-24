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

    # Query-shaped copy: the tool qualifiers people type, and the use cases they
    # describe. Each one is answered by a feature the page already offers.
    assert_select "main", /Nothing to install/i
    assert_select "section[aria-labelledby='common-questions'] summary", text: /maker or generator/i
    assert_select "main", /carol or hymn sheets/i
  end

  test "homepage offers the songbook guide for multi-song printing" do
    get root_path

    assert_response :success
    # A contextual in-body link carrying the query the guide answers.
    assert_select ".songbook-note a[href='#{print_a_songbook_path}']",
      text: /how to make a songbook/i

    structured_data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    application = structured_data.fetch("@graph").find { |node| node["@type"] == "WebApplication" }
    assert_includes application.fetch("featureList"),
      "Collect lyric sheets into one songbook and print them as one job"
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
    # The layout intent people type as "template" or "Word document".
    assert_select "section[aria-labelledby='one-page-questions'] summary", text: /template or a Word document/i
  end

  test "songbook guide owns its intent and links into the tool" do
    get print_a_songbook_path

    assert_response :success
    assert_select "title", "How to Make and Print a Songbook of Lyrics | PrintLyrics"
    assert_select "meta[name='description'][content*='one songbook']", 1
    assert_select "meta[name='robots'][content*='index, follow']", 1
    assert_select "link[rel='canonical'][href='#{print_a_songbook_url}']", 1
    assert_select "h1", "Make a songbook of lyric sheets"
    assert_select "a[href='#{root_path}']", text: /open the lyric printing tool/i
    # A contextual in-body link carrying head-query anchor text.
    assert_select ".guide-answer a[href='#{root_path}']", text: /print your lyrics/i
    assert_select "main", /one job/i
    assert_select "main", /25 songs/i
    assert_select "main", /180 days/i
    assert_select "section[aria-labelledby='songbook-questions'] details", minimum: 3
    # The document-editor alternative and the "lyric book" synonym people use.
    assert_select "section[aria-labelledby='songbook-questions'] summary", text: /songbook in Word/i
    assert_select "main", /lyric book or booklet/i

    structured_data = JSON.parse(css_select("script[type='application/ld+json']").first.text)
    assert_equal "HowTo", structured_data.fetch("@type")
    assert_equal print_a_songbook_url, structured_data.fetch("url")
    # Steps are read from the same locale keys the page renders.
    assert_equal 6, structured_data.fetch("step").length
    assert_equal structured_data.fetch("step").first.fetch("name"),
      "Make the first song's sheet"
  end

  test "crawlable pages link to each other with descriptive anchors" do
    get root_path

    assert_response :success
    assert_select ".tool-explainer", count: 1
    assert_select "[data-search-navigation]", count: 0
    assert_select "footer[data-resource-navigation]" do
      assert_select "a[href='#{print_lyrics_on_one_page_path}']", text: /one-page printing guide/i
      assert_select "a[href='#{print_a_songbook_path}']", text: /songbook printing guide/i
      assert_select "a[href='#{root_path}']", count: 0
    end

    get print_lyrics_on_one_page_path

    assert_response :success
    assert_select "[data-search-navigation]", count: 0
    assert_select "footer[data-resource-navigation]" do
      assert_select "a[href='#{root_path}']", text: /print song lyrics/i
      assert_select "a[href='#{print_a_songbook_path}']", text: /songbook printing guide/i
      assert_select "a[href='#{print_lyrics_on_one_page_path}']", count: 0
    end

    get print_a_songbook_path

    assert_response :success
    assert_select "footer[data-resource-navigation]" do
      assert_select "a[href='#{root_path}']", text: /print song lyrics/i
      assert_select "a[href='#{print_lyrics_on_one_page_path}']", text: /one-page printing guide/i
      assert_select "a[href='#{print_a_songbook_path}']", count: 0
    end
  end

  test "generated lyric page omits search navigation" do
    lyric = Lyric.create!(lyrics: "Private line")

    get lyric_path(lyric)

    assert_response :success
    assert_select "[data-search-navigation]", count: 0
  end

  test "sitemap includes the homepage and both printing guides" do
    get sitemap_path(format: :xml)

    assert_response :success
    document = Nokogiri::XML(response.body)
    locations = document.xpath("//*[local-name()='loc']").map(&:text)
    assert_includes locations, root_url
    assert_includes locations, print_lyrics_on_one_page_url
    assert_includes locations, print_a_songbook_url
  end
end
