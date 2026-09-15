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

  test "promote counts demand and refreshes source metadata" do
    song = Song.create!(source_id: 42, title: "Old", artist: "Artist")

    assert_equal 0, song.print_page_count

    song.promote!({ title: "New", artist: "Artist", album: "Record", duration_seconds: 214 })

    assert_equal 1, song.print_page_count
    assert_equal "New", song.reload.title
    assert_equal "Record", song.album
    assert_equal 214, song.duration_seconds
    assert_not_nil song.last_verified_at
  end

  test "promote keeps counting when metadata is unchanged" do
    song = Song.create!(source_id: 42, title: "Same", artist: "Artist")

    song.promote!({ title: "Same", artist: "Artist" })
    song.promote!({ title: "Same", artist: "Artist" })

    assert_equal 2, song.reload.print_page_count
  end
end
