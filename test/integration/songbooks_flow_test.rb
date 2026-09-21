require "test_helper"

class SongbooksFlowTest < ActionDispatch::IntegrationTest
  test "adding another song from a generated page goes on to the entry form" do
    lyric = Lyric.create!(lyrics: "First line", title: "First Song")

    post songbooks_path, params: { lyric_token: lyric.token, then: "add_song" }

    songbook = Songbook.last
    assert_equal [ lyric.id ], songbook.lyrics.pluck(:id)
    assert_redirected_to root_path(songbook: songbook.token)
    follow_redirect!
    assert_select ".songbook-context", /Adding to a songbook with 1 song/
  end

  test "an unknown destination value still lands on the set" do
    lyric = Lyric.create!(lyrics: "First line")

    post songbooks_path, params: { lyric_token: lyric.token, then: "https://example.com" }

    assert_redirected_to songbook_path(Songbook.last)
  end

  test "starting a songbook from an unknown page returns to the form" do
    assert_no_difference "Songbook.count" do
      post songbooks_path, params: { lyric_token: "missing-token" }
    end

    assert_redirected_to root_path
  end

  test "a set built from several sheets keeps the order they were sent in" do
    lyrics = 3.times.map { |index| Lyric.create!(lyrics: "Line #{index}", title: "Song #{index}") }

    post songbooks_path, params: { lyric_tokens: [ lyrics[2].token, lyrics[0].token, lyrics[1].token ] }

    songbook = Songbook.last
    assert_redirected_to songbook_path(songbook)
    assert_equal [ "Song 2", "Song 0", "Song 1" ], songbook.lyrics.map(&:title)
  end

  test "a set drops sheets that are unknown, expired, or repeated" do
    keep = Lyric.create!(lyrics: "Keep this", title: "Keep")
    expired = Lyric.create!(lyrics: "Gone", title: "Gone", expires_at: 1.minute.ago)

    post songbooks_path, params: {
      lyric_tokens: [ keep.token, "missing-token", expired.token, keep.token ]
    }

    assert_equal [ keep.id ], Songbook.last.lyrics.pluck(:id)
  end

  test "a set with no usable sheet returns to the form" do
    assert_no_difference "Songbook.count" do
      post songbooks_path, params: { lyric_tokens: [ "missing-token" ] }
    end

    assert_redirected_to root_path
  end

  test "a set is bounded to what one session can hold" do
    lyrics = (SongbooksController::MAX_SONGS + 2).times.map { |index| Lyric.create!(lyrics: "Line #{index}") }

    post songbooks_path, params: { lyric_tokens: lyrics.map(&:token) }

    assert_equal SongbooksController::MAX_SONGS, Songbook.last.lyrics.count
  end

  test "generating from the songbook context appends the song and lands on the set" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First line", title: "First Song"))

    post lyrics_path, params: {
      songbook: songbook.token,
      lyric: { title: "Second Song", artist: "An Artist", lyrics: "Second line" }
    }

    assert_redirected_to songbook_path(songbook)
    follow_redirect!
    assert_response :success
    assert_equal [ "First Song", "Second Song" ],
      css_select("[data-preview-song] .lyric-header h1").map(&:text)
  end

  test "a stale songbook token generates an ordinary single page" do
    post lyrics_path, params: {
      songbook: "missing-token",
      lyric: { title: "Solo", lyrics: "A line" }
    }

    assert_redirected_to lyric_path(Lyric.last)
    assert_equal 0, Songbook.count
  end

  test "the generated page event follows an appended song onto the set" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First line", title: "First Song"))

    post lyrics_path, params: {
      songbook: songbook.token,
      lyric: { title: "Second Song", lyrics: "Second line" }
    }
    follow_redirect!
    assert_select "body[data-generated-page-key='#{Lyric.last.token}']", count: 1

    get songbook_path(songbook)
    assert_select "body[data-generated-page-key]", count: 0
  end

  test "the entry form carries the songbook and ignores an unknown one" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First line"))

    get root_path(songbook: songbook.token)

    assert_response :success
    assert_select "input[name='songbook'][value='#{songbook.token}']", count: 2
    assert_select "meta[name='robots'][content='noindex, nofollow']", 1

    get root_path(songbook: "missing-token")

    assert_response :success
    assert_select "input[name='songbook']", count: 0
    assert_select "meta[name='robots'][content*='index, follow']", 1
  end

  test "the songbook survives search and selection" do
    result = LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214.0,
      plain_lyrics: "[Verse]\nLove, rising from the mists",
      synced_lyrics: nil,
      instrumental: false
    )
    client = Object.new
    client.define_singleton_method(:search) { |_| [ result ] }
    client.define_singleton_method(:find) { |_| result }
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First line"))

    with_lrc_lib_client(client) do
      post search_lyrics_path, params: { query: "judee sill", songbook: songbook.token }

      assert_response :success
      assert_select "form[action='#{select_lyrics_path}'] input[name='songbook'][value='#{songbook.token}']", count: 1

      post select_lyrics_path, params: { result_id: 42, query: "judee sill", songbook: songbook.token }

      assert_response :success
      assert_select "form[action='#{lyrics_path}'] input[name='songbook'][value='#{songbook.token}']", count: 1
    end
  end

  test "the set is not indexable and stays out of the sitemap" do
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First line"))

    get songbook_path(songbook)

    assert_response :success
    assert_select "meta[name='robots'][content='noindex, nofollow']", 1
    assert_select "link[rel='canonical'][href='#{root_url}']", 1

    get sitemap_path

    assert_response :success
    assert_no_match songbook.token, response.body
  end

  test "removing a song drops it from the set" do
    first = Lyric.create!(lyrics: "First line", title: "First Song")
    second = Lyric.create!(lyrics: "Second line", title: "Second Song")
    songbook = Songbook.start_with(first)
    songbook.append!(second)

    delete songbook_song_path(songbook, second.token)

    assert_redirected_to songbook_path(songbook)
    follow_redirect!
    assert_equal [ "First Song" ], css_select("[data-preview-song] .lyric-header h1").map(&:text)
  end

  test "removing a song from another set leaves this one alone" do
    mine = Lyric.create!(lyrics: "Mine", title: "Mine")
    theirs = Lyric.create!(lyrics: "Theirs", title: "Theirs")
    songbook = Songbook.start_with(mine)
    other = Songbook.start_with(theirs)

    delete songbook_song_path(songbook, theirs.token)

    assert_equal [ mine.id ], songbook.reload.lyrics.pluck(:id)
    assert_equal [ theirs.id ], other.reload.lyrics.pluck(:id)
  end

  test "expired and unknown songbooks return to the form" do
    expired = Songbook.create!(expires_at: 1.minute.ago)

    get songbook_path(expired)
    assert_redirected_to root_path

    get songbook_path("missing-token")
    assert_redirected_to root_path
  end
end
