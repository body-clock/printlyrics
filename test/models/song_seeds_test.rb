require "test_helper"

class SongSeedsTest < ActiveSupport::TestCase
  setup do
    Lyric.delete_all
    Song.delete_all
  end

  test "seeds twenty curated public songs without lyrics" do
    assert_difference("Song.count", 20) do
      load Rails.root.join("db/seeds.rb")
    end

    assert_equal 20, Song.indexable.count
    assert_equal 0, Song.sum(:print_page_count)

    refreshed_song = Song.find_by!(source_id: 17825857)
    refreshed_song.update!(title: "Source-refreshed title")

    assert_no_difference([ "Song.count", "Lyric.count" ]) do
      load Rails.root.join("db/seeds.rb")
    end
    assert_equal "Source-refreshed title", refreshed_song.reload.title
  end
end
