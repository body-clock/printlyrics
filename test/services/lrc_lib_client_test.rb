require "test_helper"

class LrcLibClientTest < ActiveSupport::TestCase
  test "search returns five unique results that contain lyrics" do
    rows = [
      result(id: 0, title: ""),
      result(id: 1, title: "The Kiss", album: "Judee Sill"),
      result(id: 2, title: "The Kiss", album: "Judee Sill"),
      result(id: 3, title: "The Kiss - Remastered", album: "Heart Food"),
      result(id: 4, title: "The Donor"),
      result(id: 5, title: "Jesus Was a Cross Maker"),
      result(id: 6, title: "Crayon Angels"),
      result(id: 7, title: "Lady-O"),
      result(id: 8, title: "Instrumental", instrumental: true),
      result(id: 9, title: "No Lyrics", plain_lyrics: nil, synced_lyrics: nil)
    ]
    connection = connection_with do |stub|
      stub.get("/api/search") do |env|
        assert_equal "judee sill", env.params["q"]
        [ 200, json_headers, JSON.generate(rows) ]
      end
    end

    results = LrcLibClient.new(connection: connection).search("judee sill")

    assert_equal 5, results.size
    assert_equal [ 1, 3, 4, 5, 6 ], results.map(&:id)
  end

  test "find returns printable metadata and strips timestamps when only synced lyrics exist" do
    row = result(
      id: 42,
      title: "The Kiss",
      plain_lyrics: nil,
      synced_lyrics: "[00:01.00]Love, rising from the mists\n[00:03.20]Promise me this"
    )
    connection = connection_with do |stub|
      stub.get("/api/get/42") { [ 200, json_headers, JSON.generate(row) ] }
    end

    result = LrcLibClient.new(connection: connection).find(42)

    assert_equal "The Kiss", result.title
    assert_equal "Judee Sill", result.artist
    assert_equal "Love, rising from the mists\nPromise me this", result.lyrics
    assert_equal "https://lrclib.net/api/get/42", result.source_url
  end

  test "raises a not found error for a missing result" do
    connection = connection_with do |stub|
      stub.get("/api/get/404") { [ 404, json_headers, "{}" ] }
    end

    assert_raises(LrcLibClient::NotFoundError) do
      LrcLibClient.new(connection: connection).find(404)
    end
  end

  test "catalog search can return a larger bounded result set" do
    rows = 10.times.map { |index| result(id: index + 1, title: "Song #{index}") }
    connection = connection_with do |stub|
      stub.get("/api/search") { [ 200, json_headers, JSON.generate(rows) ] }
    end

    results = LrcLibClient.new(connection: connection).search_catalog("songs", limit: 8)

    assert_equal 8, results.size
  end

  test "raises a service error when LRCLIB is unavailable" do
    connection = connection_with do |stub|
      stub.get("/api/search") { [ 503, json_headers, "{}" ] }
    end

    assert_raises(LrcLibClient::ServiceError) do
      LrcLibClient.new(connection: connection).search("the kiss")
    end
  end

  private

  def connection_with
    stubs = Faraday::Adapter::Test::Stubs.new
    yield stubs
    Faraday.new(url: "https://lrclib.net") { |faraday| faraday.adapter(:test, stubs) }
  end

  def json_headers
    { "Content-Type" => "application/json" }
  end

  def result(
    id:,
    title:,
    artist: "Judee Sill",
    album: "Heart Food",
    duration: 214.0,
    plain_lyrics: "Love, rising from the mists",
    synced_lyrics: nil,
    instrumental: false
  )
    {
      id: id,
      trackName: title,
      artistName: artist,
      albumName: album,
      duration: duration,
      plainLyrics: plain_lyrics,
      syncedLyrics: synced_lyrics,
      instrumental: instrumental
    }
  end
end
