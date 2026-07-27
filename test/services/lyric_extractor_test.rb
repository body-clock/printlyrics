require "test_helper"

class LyricExtractorTest < ActiveSupport::TestCase
  test "rejects unsupported hosts without making a request" do
    assert_raises(LyricExtractor::UnsupportedSiteError) do
      LyricExtractor.new.extract("https://example.com/some-song")
    end
  end

  test "maps unsuccessful responses to a fetch error" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/song") { [ 503, {}, "Unavailable" ] }
    end
    connection = Faraday.new(url: "https://genius.com") { |faraday| faraday.adapter(:test, stubs) }

    assert_raises(LyricExtractor::FetchError) do
      LyricExtractor.new(connection: connection).extract("https://genius.com/song")
    end
  end

  test "fetches and dispatches a supported Genius URL" do
    body = <<~HTML
      <meta property="og:title" content="Hüsker Dü – Celebrated Summer Lyrics | Genius Lyrics">
      <div data-lyrics-container="true">Love and hate was in the air</div>
    HTML
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get("/husker-du-celebrated-summer-lyrics") { [ 200, { "Content-Type" => "text/html" }, body ] }
    end
    connection = Faraday.new(url: "https://genius.com") { |faraday| faraday.adapter(:test, stubs) }

    result = LyricExtractor.new(connection: connection).extract(
      "https://genius.com/husker-du-celebrated-summer-lyrics"
    )

    assert_equal "Celebrated Summer", result.title
    assert_equal "Hüsker Dü", result.artist
  end
end
