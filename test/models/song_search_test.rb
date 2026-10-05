require "test_helper"

class SongSearchTest < ActiveSupport::TestCase
  test "blank query uses the localized validation message" do
    search = SongSearch.new(query: "")

    assert_not search.valid?
    assert_equal I18n.t("activemodel.errors.models.song_search.attributes.query.blank"),
      search.errors.first.message
  end

  test "long query uses the localized validation message" do
    search = SongSearch.new(query: "a" * 201)

    assert_not search.valid?
    assert_equal I18n.t("activemodel.errors.models.song_search.attributes.query.too_long"),
      search.errors.first.message
  end

  test "source failures propagate for callers to translate" do
    client = Object.new
    client.define_singleton_method(:search) { |_| raise LrcLibClient::ServiceError }
    search = SongSearch.new(query: "a song")

    assert_raises(LrcLibClient::ServiceError) { search.perform(client: client) }
  end

  test "empty reports a completed search with no matches" do
    client = Object.new
    client.define_singleton_method(:search) { |_| [] }
    search = SongSearch.new(query: "a song nobody wrote")

    assert search.perform(client: client)
    assert search.empty?
  end

  test "stops at the visitor's own words when they answer" do
    result = row(title: "The Kiss", artist: "Judee Sill")
    calls = []

    search = SongSearch.new(query: "judee sill the kiss")
    assert search.perform(client: client_recording(calls) { |_| [ result ] })

    assert_equal [ "judee sill the kiss" ], calls
    assert_equal [ result ], search.results
  end

  test "broadens only after the visitor's own words find nothing" do
    result = row(title: "Battle Belongs", artist: "Phil Wickham")
    calls = []
    responder = ->(query) { query == "battle belongs phil wickham" ? [ result ] : [] }

    search = SongSearch.new(query: "Battle Belongs by Phil Wickham")
    assert search.perform(client: client_recording(calls, &responder))

    assert_equal [ "battle belongs by phil wickham", "battle belongs phil wickham" ], calls
    assert_equal [ result ], search.results
  end

  test "recovers a mistyped title from a broader attempt" do
    wanted = row(title: "Rikki Don't Lose That Number", artist: "Steely Dan")
    decoy = row(title: "Rikki", artist: "Somebody Else")
    calls = []
    responder = ->(query) { query == "rikki dont" ? [ decoy, wanted ] : [] }

    search = SongSearch.new(query: "rikki dont loose thtat number")
    assert search.perform(client: client_recording(calls, &responder))

    assert_equal [ wanted ], search.results
  end

  test "stops climbing the ladder once the budget is spent" do
    calls = []
    ticks = [ 0.0, SongSearch::DEADLINE_SECONDS ]
    clock = -> { ticks.shift || SongSearch::DEADLINE_SECONDS }

    search = SongSearch.new(query: "three little witches")
    assert search.perform(client: client_recording(calls) { |_| [] }, clock: clock)

    assert_equal 1, calls.size
  end

  test "climbs the whole ladder while the budget lasts" do
    calls = []

    search = SongSearch.new(query: "three little witches")
    assert search.perform(client: client_recording(calls) { |_| [] }, clock: -> { 0.0 })

    assert_equal 3, calls.size
  end

  test "an attempt that matches a different song stays a miss" do
    decoy = row(title: "Three Little Birds", artist: "Bob Marley")
    calls = []
    responder = ->(query) { [ "three little", "three" ].include?(query) ? [ decoy ] : [] }

    search = SongSearch.new(query: "three little witches")
    assert search.perform(client: client_recording(calls, &responder))

    assert search.empty?
    assert_includes calls, "three little"
  end

  test "a source match that lacks the visitor's words is not shown" do
    wrong = row(title: "Mighty God, Father, Friend", artist: "Ghost Ship")
    calls = []

    search = SongSearch.new(query: "God Never Gave Up on Me")
    assert search.perform(client: client_recording(calls) { |_| [ wrong ] })

    assert search.empty?
  end

  test "asks separated fields when the visitor split the title and artist" do
    result = row(title: "Battle Belongs", artist: "Phil Wickham")
    fields = []

    client = Object.new
    client.define_singleton_method(:search) { |_| [] }
    client.define_singleton_method(:search_by_fields) do |track_name:, artist_name:|
      fields << [ track_name, artist_name ]
      [ result ]
    end

    search = SongSearch.new(query: "Battle Belongs by Phil Wickham")
    assert search.perform(client: client)

    assert_equal [ [ "battle belongs", "phil wickham" ] ], fields
    assert_equal [ result ], search.results
  end

  private

  def client_recording(calls, &responder)
    Object.new.tap do |client|
      client.define_singleton_method(:search) do |query|
        calls << query
        responder.call(query)
      end
    end
  end

  def row(id: 1, title:, artist: "Somebody", album: "Some Album")
    LrcLibResult.new(
      id: id,
      title: title,
      artist: artist,
      album: album,
      duration: 214.0,
      plain_lyrics: "A printable line",
      synced_lyrics: nil,
      instrumental: false
    )
  end
end
