require "test_helper"

class LyricPageCreationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    Lyric.delete_all
    Song.delete_all
  end

  teardown do
    Lyric.delete_all
    Song.delete_all
  end

  test "valid token atomically creates lyric and promotes song" do
    operation = build_operation

    assert_difference([ "Lyric.count", "Song.count" ], 1) do
      assert operation.save
    end

    lyric = operation.lyric
    song = lyric.song
    assert_equal "Edited title", lyric.title
    assert_equal "Edited artist", lyric.artist
    assert_equal "The Kiss", song.title
    assert_equal "Judee Sill", song.artist
    assert_equal "https://lrclib.net/api/get/42", lyric.source_url
    assert_equal 1, song.print_page_count
    assert song.indexable?
    assert song.last_verified_at
  end

  test "repeated generation reuses song and increments demand" do
    first = build_operation
    assert first.save
    original_song = first.lyric.song.reload
    original_slug = original_song.slug
    original_updated_at = original_song.updated_at

    travel 1.hour do
      second = build_operation
      assert_no_difference("Song.count") { assert second.save }

      song = second.lyric.song.reload
      assert_equal 2, song.print_page_count
      assert_equal original_slug, song.slug
      assert_equal original_updated_at, song.updated_at
      assert_operator song.last_verified_at, :>, original_song.last_verified_at
    end
  end

  test "concurrent generation reuses the song and increments demand safely" do
    operations = 2.times.map { build_operation }
    ready = Queue.new
    start = Queue.new

    threads = operations.map do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          start.pop
          operation.save
        end
      end
    end

    operations.size.times { ready.pop }
    operations.size.times { start << true }
    results = threads.map(&:value)

    assert_equal [ true, true ], results
    assert_equal 1, Song.count
    assert_equal 2, Lyric.count
    assert_equal 2, Song.first.print_page_count
  end

  test "invalid token safely degrades to manual creation" do
    operation = LyricPageCreation.new(
      attributes: {
        title: "Manual",
        artist: "Person",
        lyrics: "My own line",
        source_url: "https://lrclib.net/api/get/999"
      },
      catalog_token: "forged"
    )

    assert_difference("Lyric.count", 1) { assert operation.save }
    assert_no_difference("Song.count") { }
    assert_nil operation.lyric.song
    assert_nil operation.lyric.source_url
  end

  test "invalid lyric rolls back song promotion" do
    operation = build_operation(lyrics: " ")

    assert_no_difference([ "Lyric.count", "Song.count" ]) do
      refute operation.save
    end
    assert_includes operation.lyric.errors[:lyrics], "can't be blank"
  end

  private

  def build_operation(lyrics: "A printable line")
    result = LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: lyrics,
      synced_lyrics: nil,
      instrumental: false
    )

    LyricPageCreation.new(
      attributes: {
        title: "Edited title",
        artist: "Edited artist",
        lyrics: lyrics,
        source_url: result.source_url
      },
      catalog_token: SongCatalogToken.issue(result)
    )
  end
end
