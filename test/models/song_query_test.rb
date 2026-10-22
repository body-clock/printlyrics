require "test_helper"

class SongQueryTest < ActiveSupport::TestCase
  test "strips the wrapping a visitor adds around a title" do
    assert_equal "jamaica farewell", SongQuery.new("LYRICS JAMAICA FAREWELL").cleaned
    assert_equal "battle belongs", SongQuery.new("Battle Belongs (Official Lyric Video)").cleaned
    assert_equal "loadmaster", SongQuery.new("loadmaster song").cleaned
  end

  test "leaves a link with nothing to search for" do
    assert SongQuery.new("https://open.spotify.com/track/0J87ieRdbGPItHA6qc3KCr?si=abc").blank?
  end

  test "trims the edges only, so a title's own words survive in the middle" do
    assert_equal "boom boom video night", SongQuery.new("Boom Boom Video Night").cleaned
  end

  test "treats a separated title and artist as fields" do
    query = SongQuery.new("Battle Belongs by Phil Wickham")

    assert_equal [ "battle belongs", "phil wickham" ], query.field_parts
  end

  test "asks in the visitor's own words before broadening" do
    attempts = SongQuery.new("Battle Belongs by Phil Wickham").attempts

    assert_equal [
      [ :keywords, "battle belongs by phil wickham" ],
      [ :keywords, "battle belongs phil wickham" ],
      [ :fields, "battle belongs phil wickham" ],
      [ :keywords, "belongs" ],
      [ :keywords, "battle belongs" ],
      [ :keywords, "belongs phil" ],
      [ :keywords, "phil wickham" ],
      [ :keywords, "belongs phil wickham" ],
      [ :keywords, "battle phil wickham" ],
      [ :keywords, "battle belongs wickham" ]
    ], attempts.map { |attempt| [ attempt.kind, attempt.params[:q] || attempt.params.values.join(" ") ] }
  end

  test "keeps a title that merely contains the word by" do
    query = SongQuery.new("Stand by Me")

    # "by" is a field separator only when the visitor used it that way; the
    # ladder still opens with the phrase exactly as typed.
    assert_equal "stand by me", query.attempts.first.params[:q]
  end

  test "makes one attempt when the visitor typed one word" do
    assert_equal [ [ :keywords, "pasantosa" ] ],
      SongQuery.new("Pasantosa").attempts.map { |attempt| [ attempt.kind, attempt.params[:q] ] }
  end

  test "accepts the record the visitor meant despite a typo" do
    query = SongQuery.new("rikki dont loose thtat number")

    assert query.accepts?([ row(title: "Rikki Don't Lose That Number", artist: "Steely Dan") ])
  end

  test "accepts the record the visitor meant when the source spells a word its own way" do
    # The source holds "Taio Cruz"; the visitor typed "Taio Cruise", which is
    # three edits from it and no prefix of it, so the typo budget cannot reach.
    assert SongQuery.new("Dynamite taio cruise")
      .accepts?([ row(title: "Dynamite", artist: "Taio Cruz") ])
  end

  test "forgives one differently spelled word and not two" do
    # Every word here only shares three letters with the record's, so one
    # forgiven word does not carry a record the visitor did not ask for.
    assert_not SongQuery.new("brittany sparce womanizer")
      .accepts?([ row(title: "Woman", artist: "Britney Spars") ])
  end

  test "accepts a record that drops words the source never stored" do
    assert SongQuery.new("HAPPY TRAILS TO YOU").accepts?([ row(title: "Happy Trails", artist: "Quicksilver Messenger Service") ])
  end

  test "rejects a record that only shares the query's common words" do
    assert_not SongQuery.new("three little witches").accepts?([ row(title: "Three Little Birds", artist: "Bob Marley") ])
    assert_not SongQuery.new("Free, Larnelle Harris").accepts?([ row(title: "Unbelievable Love", artist: "Larnelle") ])
  end

  test "rejects the unrelated records the source answers some queries with" do
    assert_not SongQuery.new("God Never Gave Up on Me")
      .accepts?([ row(title: "Mighty God, Father, Friend", artist: "Ghost Ship") ])
    assert_not SongQuery.new("Blink james downey")
      .accepts?([ row(title: "I Miss You (James Guthrie Mix)", artist: "Blink-182") ])
  end

  test "does not count the album among the words the visitor typed" do
    assert_not SongQuery.new("God Never Gave Up on Me")
      .accepts?([ row(title: "Mighty God", artist: "Ghost Ship", album: "God Never Gave Up on Me") ])
  end

  test "does not accept a shorter word in place of the visitor's longer one" do
    assert_not SongQuery.new("Blink james downey")
      .accepts?([ row(title: "I Miss You (James Guthrie Mix)", artist: "Blink-182", album: "Down CDS") ])
  end

  test "keeps a record that carries every word the visitor typed" do
    assert SongQuery.new("Battle Belongs by Phil Wickham")
      .accepts?([ row(title: "Battle Belongs", artist: "Phil Wickham") ])
  end

  test "does not accept a record when the query has no significant words" do
    result = row(title: "The Kiss", artist: "Judee Sill")

    assert_not SongQuery.new("the").accepts?([ result ])
    assert_not SongQuery.new("a").accepts?([ result ])
    assert_not SongQuery.new("T").accepts?([ result ])
  end

  test "asks a compound title the visitor split into two words" do
    query = SongQuery.new("Margarita Ville")

    assert_includes query.attempts.map { |attempt| attempt.params[:q] }, "margaritaville"
    assert query.accepts?([ row(title: "Margaritaville", artist: "Jimmy Buffett") ])
  end

  test "does not accept a compound that only matches the artist" do
    assert_not SongQuery.new("Back Street")
      .accepts?([ row(title: "I Want It That Way", artist: "Backstreet Boys") ])
  end

  test "asks an adjacent pair beyond the first two words" do
    attempts = SongQuery.new("seven lucas graham").attempts.map { |attempt| attempt.params[:q] }

    assert_includes attempts, "lucas graham"
    assert SongQuery.new("a living prayer allison kraus")
      .accepts?([ row(title: "A Living Prayer", artist: "Alison Krauss") ])
  end

  test "asks the query without the word the source cannot match" do
    attempts = SongQuery.new("ashley mcbride kitchen light on").attempts.map { |attempt| attempt.params[:q] }

    assert_includes attempts, "ashley kitchen light"
  end

  test "drops a trailing qualifier before the leading words" do
    attempts = SongQuery.new("Battle Belongs Phil Wickham Acoustic").attempts.map { |attempt| attempt.params[:q] }

    assert_includes attempts, "battle belongs phil wickham"
  end

  test "asks each word alone, longest first" do
    attempts = SongQuery.new("Joanne Osborne").attempts.map { |attempt| attempt.params[:q] }

    assert_includes attempts, "osborne"
    assert_includes attempts, "joanne"
    assert_operator attempts.index("osborne"), :<, attempts.index("joanne")
  end

  test "bounds the ladder so a long query cannot ask without limit" do
    query = SongQuery.new("battle belongs today by phil wickham")

    assert_equal SongQuery::ATTEMPT_LIMIT, query.attempts.size
  end

  test "ranks the closest record first" do
    exact = row(id: 1, title: "Battle Belongs", artist: "Phil Wickham")
    partial = row(id: 2, title: "Belongs", artist: "Nobody")

    assert_equal [ exact, partial ], SongQuery.new("battle belongs phil wickham").rank([ partial, exact ])
  end

  private

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
