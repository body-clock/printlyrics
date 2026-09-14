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

    assert lookup.lyric.present?
    assert lookup.catalog_token
    assert_equal 42, SongCatalogToken.verify(lookup.catalog_token).fetch(:source_id)
  end

  test "propagates source errors for callers to translate" do
    lookup = SongLookup.new

    assert_raises(LrcLibClient::NotFoundError) do
      lookup.perform("404", client: failing_client(LrcLibClient::NotFoundError))
    end

    assert_raises(LrcLibClient::ServiceError) do
      lookup.perform("42", client: failing_client(LrcLibClient::ServiceError))
    end
  end

  private

  def failing_client(error)
    Object.new.tap do |client|
      client.define_singleton_method(:find) { |_| raise error }
    end
  end
end
