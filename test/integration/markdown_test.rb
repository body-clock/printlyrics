require "test_helper"

class MarkdownTest < ActionDispatch::IntegrationTest
  test "one-page guide .md route serves clean markdown" do
    get "/print-lyrics-on-one-page.md"

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match "# Print lyrics on one page", response.body
    assert_match "## The short answer", response.body
    assert_match "## Try two columns", response.body
    assert_match "[print your lyrics with PrintLyrics](", response.body
  end

  test "songbook guide .md route serves clean markdown" do
    get "/print-a-songbook.md"

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match "# Make a songbook of lyric sheets", response.body
    assert_match "## Make the first song's sheet", response.body
  end

  test "homepage markdown twin lives at /index.md" do
    get "/index.md"

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match "# Find, format, and print song lyrics", response.body
    assert_match "## Questions about printing song lyrics", response.body
    assert_match "[one-page printing guide](", response.body
  end

  test "content negotiation serves markdown when Accept prefers it" do
    get print_lyrics_on_one_page_path,
      headers: { "Accept" => "text/markdown, text/html;q=0.9" }

    assert_response :success
    assert_equal "text/markdown", response.media_type
    assert_match "# Print lyrics on one page", response.body
  end

  test "HTML responses advertise the markdown twin and vary on Accept" do
    get print_lyrics_on_one_page_path

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.headers["Vary"].to_s, "Accept"
    assert_includes response.headers["Link"],
      %(</print-lyrics-on-one-page.md>; rel="alternate"; type="text/markdown")
    assert_select "link[rel='alternate'][type='text/markdown']" \
      "[href='#{print_lyrics_on_one_page_url}.md']", 1
  end

  test "markdown responses link back to the HTML page" do
    get "/print-lyrics-on-one-page.md"

    assert_includes response.headers["Vary"].to_s, "Accept"
    assert_includes response.headers["Link"],
      %(</print-lyrics-on-one-page>; rel="alternate"; type="text/html")
  end

  test "homepage HTML advertises /index.md as its markdown twin" do
    get root_path

    assert_select "link[rel='alternate'][type='text/markdown'][href='#{root_url}index.md']", 1
  end

  test "llms.txt lists the markdown versions of the crawlable pages" do
    get "/llms.txt"

    assert_response :success
    assert_match "# PrintLyrics", response.body
    assert_match "printlyrics.app/index.md", response.body
    assert_match "printlyrics.app/print-lyrics-on-one-page.md", response.body
    assert_match "printlyrics.app/print-a-songbook.md", response.body
  end

  test "llms-full.txt redirects to the homepage markdown" do
    get "/llms-full.txt"

    assert_response :redirect
    assert_redirected_to "/index.md"
  end

  test "non-public pages have no markdown twin link" do
    lyric = Lyric.create!(lyrics: "Private line")

    get lyric_path(lyric)

    assert_response :success
    assert_select "link[rel='alternate'][type='text/markdown']", count: 0
  end
end
