require "test_helper"

class PopularSongMatcherTest < ActiveSupport::TestCase
  test "returns one printable exact title and artist match" do
    candidate = apple_candidate(title: "The Kiss", artist: "The Judee Sill")
    exact = result(id: 42, title: "the kiss", artist: "Judee Sill")
    client = fake_client([ exact, result(id: 43, title: "The Kiss (Live)", artist: "Judee Sill") ])

    assert_equal exact, PopularSongMatcher.new(client: client).match(candidate)
  end

  test "rejects alternate versions and ambiguous exact matches" do
    candidate = apple_candidate(title: "The Kiss", artist: "Judee Sill")

    refute PopularSongMatcher.new(client: fake_client([ result(id: 1, title: "The Kiss (Live)") ])).match(candidate)
    refute PopularSongMatcher.new(client: fake_client([ result(id: 1), result(id: 2) ])).match(candidate)
  end

  private

  def fake_client(results)
    Object.new.tap do |client|
      client.define_singleton_method(:search_catalog) do |query|
        raise "unexpected query" unless query == "The Kiss Judee Sill" || query == "The Kiss The Judee Sill"
        results
      end
    end
  end

  def apple_candidate(title:, artist:)
    AppleSongCandidate.new(id: "1", title: title, artist: artist, url: "https://music.apple.com/us/album/song/1")
  end

  def result(id:, title: "The Kiss", artist: "Judee Sill")
    LrcLibResult.new(id: id, title: title, artist: artist, album: "Album", duration: 120, plain_lyrics: "Lyrics", synced_lyrics: nil, instrumental: false)
  end
end
