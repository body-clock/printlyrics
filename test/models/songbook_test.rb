require "test_helper"

class SongbookTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "generates a stable URL-safe token before validation" do
    songbook = Songbook.new

    assert songbook.valid?
    assert_match(/\A[A-Za-z0-9_-]{16}\z/, songbook.token)
    assert_equal songbook.token, songbook.to_param
  end

  test "start with keeps the first song and appends later ones in order" do
    first = Lyric.create!(lyrics: "First line", title: "First")
    songbook = Songbook.start_with(first)

    assert_equal [ first.id ], songbook.lyrics.pluck(:id)

    songbook.append!(Lyric.create!(lyrics: "Second line", title: "Second"))
    songbook.append!(Lyric.create!(lyrics: "Third line", title: "Third"))

    assert_equal %w[First Second Third], songbook.lyrics.map(&:title)
    assert_equal [ 1, 2, 3 ], songbook.entries.map(&:position)
  end

  test "start with keeps several sheets in the order given" do
    first = Lyric.create!(lyrics: "First line", title: "First")
    second = Lyric.create!(lyrics: "Second line", title: "Second")

    songbook = Songbook.start_with(second, first)

    assert_equal [ second.id, first.id ], songbook.lyrics.pluck(:id)
  end

  test "a songbook is a set once it holds more than one song" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First line"))

    assert_not songbook.a_set?

    songbook.append!(Lyric.create!(lyrics: "Second line"))

    assert songbook.a_set?
  end

  test "removing a song leaves the rest of the set in order" do
    lyrics = 3.times.map { |index| Lyric.create!(lyrics: "Line #{index}", title: "Song #{index}") }
    songbook = Songbook.start_with(lyrics.first)
    songbook.append!(lyrics.second)
    songbook.append!(lyrics.third)

    songbook.remove!(lyrics.second)

    assert_equal [ "Song 0", "Song 2" ], songbook.reload.lyrics.map(&:title)
  end

  test "removing a song that is not in the set changes nothing" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "A line"))

    songbook.remove!(Lyric.create!(lyrics: "Another line"))

    assert_equal 1, songbook.entries.count
  end

  test "new songbooks expire after 180 days" do
    travel_to Time.zone.local(2026, 7, 27, 12) do
      songbook = Songbook.create!

      assert_equal 180.days.from_now, songbook.expires_at
    end
  end

  test "renew retention extends the set and every song in it" do
    first = Lyric.create!(lyrics: "First line", expires_at: 1.day.from_now)
    second = Lyric.create!(lyrics: "Second line", expires_at: 2.days.from_now)
    songbook = Songbook.start_with(first)
    songbook.append!(second)
    songbook.update_column(:expires_at, 3.days.from_now)

    travel 1.hour do
      renewed = Songbook.renew_retention!(songbook.token)

      assert_equal songbook.id, renewed.id
      assert_in_delta 180.days.from_now, renewed.expires_at, 1.second
      assert_in_delta 180.days.from_now, first.reload.expires_at, 1.second
      assert_in_delta 180.days.from_now, second.reload.expires_at, 1.second
    end
  end

  test "renew retention rejects expired and unknown tokens" do
    songbook = Songbook.create!(expires_at: 1.minute.ago)

    assert_raises(ActiveRecord::RecordNotFound) { Songbook.renew_retention!(songbook.token) }
    assert_raises(ActiveRecord::RecordNotFound) { Songbook.renew_retention!("missing-token") }
  end

  test "purge expired removes only expired songbooks" do
    active = Songbook.create!
    expired = Songbook.create!(expires_at: 1.minute.ago)

    assert_equal 1, Songbook.purge_expired!
    assert Songbook.exists?(active.id)
    assert_not Songbook.exists?(expired.id)
  end

  test "purging an expired song leaves the rest of the set readable" do
    kept = Lyric.create!(lyrics: "Keep this line", title: "Keeper")
    expired = Lyric.create!(lyrics: "Gone soon", title: "Goner", expires_at: 1.minute.ago)
    songbook = Songbook.start_with(kept)
    songbook.append!(expired)

    Lyric.purge_expired!

    assert_equal [ kept.id ], songbook.reload.lyrics.pluck(:id)
    assert_equal 1, songbook.entries.count
  end
end
