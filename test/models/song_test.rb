require "test_helper"

class SongTest < ActiveSupport::TestCase
  test "generates a stable source-id-suffixed slug" do
    song = Song.create!(source_id: 42, title: "The Kiss", artist: "Judee Sill")

    assert_equal "judee-sill-the-kiss-42", song.slug

    song.update!(title: "The Kiss (Remastered)", artist: "Judee Lynn Sill")
    assert_equal "judee-sill-the-kiss-42", song.slug
  end

  test "requires bounded verified metadata" do
    song = Song.new(source_id: 1, title: "", artist: "")

    refute song.valid?
    assert_includes song.errors[:title], "can't be blank"
    assert_includes song.errors[:artist], "can't be blank"

    song.title = "x" * 201
    song.artist = "y" * 201
    refute song.valid?
    assert_includes song.errors[:title], "is too long (maximum is 200 characters)"
    assert_includes song.errors[:artist], "is too long (maximum is 200 characters)"
  end

  test "is indexable only while promoted and available" do
    song = Song.new(indexable_at: Time.current)

    assert song.indexable?

    song.unavailable_at = Time.current
    refute song.indexable?
  end

  test "popular and archive scopes separate current eligible songs" do
    current = Song.create!(source_id: 1, title: "Current", artist: "Zulu", indexable_at: Time.current, popular_rank: 1)
    archived = Song.create!(source_id: 2, title: "Archived", artist: "Alpha", indexable_at: Time.current)
    Song.create!(source_id: 3, title: "Private", artist: "Beta", popular_rank: 2)
    Song.create!(source_id: 4, title: "Gone", artist: "Gamma", indexable_at: Time.current, unavailable_at: Time.current, popular_rank: 3)

    assert_equal [ current ], Song.popular.to_a
    assert_equal [ archived ], Song.archive.to_a
  end

  test "popular rank is limited to the visible chart" do
    song = Song.new(source_id: 1, title: "Song", artist: "Artist", popular_rank: 21)

    refute song.valid?
    assert_includes song.errors[:popular_rank], "is not included in the list"
  end
end
