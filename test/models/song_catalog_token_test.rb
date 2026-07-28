require "test_helper"

class SongCatalogTokenTest < ActiveSupport::TestCase
  test "round trips verified non-lyric metadata" do
    token = SongCatalogToken.issue(result)

    assert_equal(
      {
        source_id: 42,
        title: "The Kiss",
        artist: "Judee Sill",
        album: "Heart Food",
        duration_seconds: 214
      },
      SongCatalogToken.verify(token)
    )
    refute_includes token, "Love, rising"
  end

  test "rejects tampered expired and wrong-purpose tokens" do
    token = SongCatalogToken.issue(result)
    assert_nil SongCatalogToken.verify("#{token}tampered")

    travel 31.minutes do
      assert_nil SongCatalogToken.verify(token)
    end

    wrong_purpose = Rails.application.message_verifier(:song_catalog).generate(
      { source_id: 42 },
      purpose: "something-else"
    )
    assert_nil SongCatalogToken.verify(wrong_purpose)
  end

  private

  def result
    LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214.4,
      plain_lyrics: "Love, rising",
      synced_lyrics: nil,
      instrumental: false
    )
  end
end
