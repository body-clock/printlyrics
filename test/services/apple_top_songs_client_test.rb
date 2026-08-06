require "test_helper"

class AppleTopSongsClientTest < ActiveSupport::TestCase
  test "returns ranked candidates from the top 25 feed" do
    connection = connection_with do |stub|
      stub.get("/api/v2/us/music/most-played/25/songs.json") do
        [ 200, json_headers, JSON.generate(feed: { results: [ candidate(id: "1"), candidate(id: "2") ] }) ]
      end
    end

    candidates = AppleTopSongsClient.new(connection: connection).fetch

    assert_equal [ "1", "2" ], candidates.map(&:id)
  end

  test "rejects an invalid candidate rather than publishing a partial response" do
    connection = connection_with do |stub|
      stub.get("/api/v2/us/music/most-played/25/songs.json") do
        [ 200, json_headers, JSON.generate(feed: { results: [ candidate(id: "1"), candidate(id: "2", url: "https://example.com/song") ] }) ]
      end
    end

    assert_raises(AppleTopSongsClient::ServiceError) do
      AppleTopSongsClient.new(connection: connection).fetch
    end
  end

  test "raises a service error for upstream and parsing failures" do
    [ [ 503, "{}" ], [ 200, "not json" ], [ 200, "[]" ], [ 200, JSON.generate(feed: {}) ] ].each do |status, body|
      connection = connection_with { |stub| stub.get("/api/v2/us/music/most-played/25/songs.json") { [ status, json_headers, body ] } }

      assert_raises(AppleTopSongsClient::ServiceError) do
        AppleTopSongsClient.new(connection: connection).fetch
      end
    end
  end

  private

  def connection_with
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs
    Faraday.new(url: "https://rss.marketingtools.apple.com") { |faraday| faraday.adapter(:test, stubs) }
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end

  def candidate(id:, url: "https://music.apple.com/us/album/song/#{id}")
    { id: id, name: "Song #{id}", artistName: "Artist #{id}", url: url }
  end
end
