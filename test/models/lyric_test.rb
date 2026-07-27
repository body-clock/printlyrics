require "test_helper"

class LyricTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "generates a stable URL-safe token before validation" do
    lyric = Lyric.new(lyrics: "First line")

    assert lyric.valid?
    assert_match(/\A[A-Za-z0-9_-]{16}\z/, lyric.token)
    assert_equal lyric.token, lyric.to_param
  end

  test "requires lyrics" do
    lyric = Lyric.new(lyrics: " \n ")

    assert_not lyric.valid?
    assert_includes lyric.errors[:lyrics], "can't be blank"
  end

  test "allows title and artist to be omitted" do
    assert Lyric.new(lyrics: "First line").valid?
  end

  test "splits lyrics into stanzas on blank lines" do
    lyric = Lyric.new(lyrics: "[Verse]\nFirst line\r\n\r\n  \r\n[Chorus]\nSecond line")

    assert_equal [ "[Verse]\nFirst line", "[Chorus]\nSecond line" ], lyric.stanzas
  end

  test "new lyrics expire after 180 days" do
    travel_to Time.zone.local(2026, 7, 27, 12) do
      lyric = Lyric.create!(lyrics: "First line")

      assert_equal 180.days.from_now, lyric.expires_at
    end
  end

  test "active excludes expired lyrics" do
    active = Lyric.create!(lyrics: "Still here")
    expired = Lyric.create!(lyrics: "Gone", expires_at: 1.minute.ago)

    assert_includes Lyric.active, active
    assert_not_includes Lyric.active, expired
  end

  test "renew retention extends expiry from the current time" do
    lyric = Lyric.create!(lyrics: "First line", expires_at: 1.day.from_now)

    travel 1.hour do
      lyric.renew_retention!

      assert_in_delta 180.days.from_now, lyric.reload.expires_at, 1.second
    end
  end

  test "purge expired removes only expired lyrics" do
    active = Lyric.create!(lyrics: "Still here")
    expired = Lyric.create!(lyrics: "Gone", expires_at: 1.minute.ago)

    assert_equal 1, Lyric.purge_expired!
    assert Lyric.exists?(active.id)
    assert_not Lyric.exists?(expired.id)
  end
end
