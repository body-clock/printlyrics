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

  test "search drops a record whose synced lyrics have no printable text" do
    rows = [ result(id: 9, title: "Timestamps Only", plain_lyrics: nil, synced_lyrics: "[00:01.00]\n[00:02.00]") ]
    connection = connection_with do |stub|
      stub.get("/api/search") { [ 200, json_headers, JSON.generate(rows) ] }
    end

    assert_empty LrcLibClient.new(connection: connection).search("timestamps only")
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

  test "retries once when the source is busy and answers on the second try" do
    rows = [ result(id: 1, title: "The Kiss") ]
    calls = 0
    connection = connection_with do |stub|
      stub.get("/api/search") do
        calls += 1
        if calls == 1
          [ 503, json_headers.merge("Retry-After" => "1"), "{}" ]
        else
          [ 200, json_headers, JSON.generate(rows) ]
        end
      end
    end
    waits = []

    results = LrcLibClient.new(connection: connection, sleeper: ->(seconds) { waits << seconds }).search("the kiss")

    assert_equal [ 1 ], results.map(&:id)
    assert_equal [ 1.0 ], waits
  end

  test "waits no longer than the cap even when the source asks for more" do
    connection = connection_with do |stub|
      stub.get("/api/search") { [ 429, json_headers.merge("Retry-After" => "30"), "{}" ] }
    end
    waits = []

    assert_raises(LrcLibClient::ServiceError) do
      LrcLibClient.new(connection: connection, sleeper: ->(seconds) { waits << seconds }).search("the kiss")
    end

    assert_equal [ LrcLibClient::MAX_RETRY_WAIT, LrcLibClient::MAX_RETRY_WAIT ], waits
  end

  test "retries twice when the source is busy and answers on the third try" do
    rows = [ result(id: 1, title: "The Kiss") ]
    calls = 0
    connection = connection_with do |stub|
      stub.get("/api/search") do
        calls += 1
        if calls < 3
          [ 503, json_headers.merge("Retry-After" => "1"), "{}" ]
        else
          [ 200, json_headers, JSON.generate(rows) ]
        end
      end
    end
    waits = []

    results = LrcLibClient.new(connection: connection, sleeper: ->(seconds) { waits << seconds }).search("the kiss")

    assert_equal [ 1 ], results.map(&:id)
    assert_equal [ 1.0, 1.0 ], waits
  end

  test "reports the source's status and explanation when LRCLIB stays unavailable" do
    body = JSON.generate(
      name: "ServerOverloaded",
      message: "The server is busy, please retry in a moment",
      statusCode: 503
    )
    connection = connection_with do |stub|
      stub.get("/api/search") { [ 503, json_headers, body ] }
    end
    waits = []

    error = assert_raises(LrcLibClient::ServiceError) do
      LrcLibClient.new(connection: connection, sleeper: ->(seconds) { waits << seconds }).search("the kiss")
    end

    assert_equal 2, waits.size
    assert_equal "/api/search", error.endpoint
    assert_equal 503, error.status
    assert_equal 3, error.attempts
    assert_equal "ServerOverloaded: The server is busy, please retry in a moment", error.detail
    assert_match(/answered 503/, error.message)
    assert_match(/3 attempts/, error.message)
    refute_includes error.message, "the kiss"
  end

  test "a one-shot search does not retry a busy source" do
    calls = 0
    connection = connection_with do |stub|
      stub.get("/api/search") do
        calls += 1
        [ 503, json_headers, "{}" ]
      end
    end
    waits = []

    error = assert_raises(LrcLibClient::ServiceError) do
      LrcLibClient.new(connection: connection, sleeper: ->(seconds) { waits << seconds })
        .search("the kiss", retries: false)
    end

    assert_equal 1, calls
    assert_empty waits
    assert_equal 1, error.attempts
  end

  test "stops retrying once the retry budget is spent" do
    connection = connection_with do |stub|
      stub.get("/api/search") { [ 503, json_headers, "{}" ] }
    end
    waits = []
    times = [ 0.0, 0.1, LrcLibClient::RETRY_BUDGET_SECONDS ]
    clock = -> { times.shift || LrcLibClient::RETRY_BUDGET_SECONDS }

    error = assert_raises(LrcLibClient::ServiceError) do
      LrcLibClient.new(
        connection: connection,
        sleeper: ->(seconds) { waits << seconds },
        clock: clock
      ).search("the kiss")
    end

    assert_equal [ LrcLibClient::DEFAULT_RETRY_WAIT ], waits
    assert_equal 2, error.attempts
  end

  test "search by fields asks the title and artist separately" do
    rows = [ result(id: 7, title: "Battle Belongs", artist: "Phil Wickham") ]
    connection = connection_with do |stub|
      stub.get("/api/search") do |env|
        assert_equal "Battle Belongs", env.params["track_name"]
        assert_equal "Phil Wickham", env.params["artist_name"]
        [ 200, json_headers, JSON.generate(rows) ]
      end
    end

    results = LrcLibClient.new(connection: connection)
      .search_by_fields(track_name: "Battle Belongs", artist_name: "Phil Wickham")

    assert_equal [ 7 ], results.map(&:id)
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
