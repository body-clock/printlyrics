require "test_helper"

class SongLookupTest < ActiveSupport::TestCase
  test "successful lookup exposes a signed catalog token without persisting" do
    result = LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: "Love, rising",
      synced_lyrics: nil,
      instrumental: false
    )
    client = Object.new
    client.define_singleton_method(:find) { |_| result }
    lookup = SongLookup.new

    assert_no_difference([ "Lyric.count", "Song.count" ]) do
      lookup.perform("42", client: client)
    end

    assert lookup.success?
    assert lookup.catalog_token
    assert_equal 42, SongCatalogToken.verify(lookup.catalog_token).fetch(:source_id)
  end
end
