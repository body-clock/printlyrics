require "test_helper"

class LyricExtractors::GeniusTest < ActiveSupport::TestCase
  test "extracts metadata and joins split lyric containers" do
    html = <<~HTML
      <html>
        <head><meta property="og:title" content="Judee Sill – The Kiss Lyrics | Genius Lyrics"></head>
        <body>
          <div data-lyrics-container="true">
            <div data-exclude-from-selection="true">The Kiss Lyrics</div>
            [Verse 1]<br>Love, rising from the mists
          </div>
          <div data-lyrics-container="true">[Chorus]<br>May I be this way forever</div>
        </body>
      </html>
    HTML

    result = LyricExtractors::Genius.new.parse(html)

    assert_equal "The Kiss", result.title
    assert_equal "Judee Sill", result.artist
    assert_equal "[Verse 1]\nLove, rising from the mists\n\n[Chorus]\nMay I be this way forever", result.lyrics
  end

  test "raises a parse error when lyric containers are absent" do
    assert_raises(LyricExtractor::ParseError) do
      LyricExtractors::Genius.new.parse("<html><head></head><body></body></html>")
    end
  end
end
