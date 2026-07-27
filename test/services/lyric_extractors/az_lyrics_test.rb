require "test_helper"

class LyricExtractors::AzLyricsTest < ActiveSupport::TestCase
  test "extracts title artist and lyrics from the main unclassed div" do
    html = <<~HTML
      <html>
        <head><title>The Blue Nile - Tinseltown In The Rain Lyrics | AZLyrics.com</title></head>
        <body>
          <main class="main-page">
            <div class="col-xs-12 col-lg-8 text-center">
              <div class="ringtone">Get the ringtone</div>
              <div>
                [Verse 1]<br>
                Why did we ever come so far?<br><br>
                [Chorus]<br>
                Tinseltown in the rain
              </div>
            </div>
          </main>
        </body>
      </html>
    HTML

    result = LyricExtractors::AzLyrics.new.parse(html)

    assert_equal "Tinseltown In The Rain", result.title
    assert_equal "The Blue Nile", result.artist
    assert_equal "[Verse 1]\nWhy did we ever come so far?\n\n[Chorus]\nTinseltown in the rain", result.lyrics
  end
end
