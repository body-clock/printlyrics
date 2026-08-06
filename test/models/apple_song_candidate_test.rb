require "test_helper"

class AppleSongCandidateTest < ActiveSupport::TestCase
  test "builds a candidate from a valid feed row" do
    candidate = AppleSongCandidate.from_api(
      "id" => "123",
      "name" => "The Kiss",
      "artistName" => "Judee Sill",
      "url" => "https://music.apple.com/us/album/the-kiss/123?i=456"
    )

    assert_equal "123", candidate.id
    assert_equal "The Kiss", candidate.title
    assert_equal "Judee Sill", candidate.artist
    assert_equal "https://music.apple.com/us/album/the-kiss/123?i=456", candidate.url
  end

  test "rejects missing metadata and non Apple destinations" do
    assert_raises(AppleSongCandidate::InvalidError) do
      AppleSongCandidate.from_api("id" => "123", "name" => "", "artistName" => "Artist", "url" => "https://music.apple.example/song")
    end

    assert_raises(AppleSongCandidate::InvalidError) do
      AppleSongCandidate.from_api("id" => "not-a-number", "name" => "Song", "artistName" => "Artist", "url" => "https://music.apple.com/song")
    end
  end
end
