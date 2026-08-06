require "test_helper"

class SongsFlowTest < ActionDispatch::IntegrationTest
  test "song routes are public and load is post only" do
    assert_routing "/songs", controller: "songs", action: "index"
    assert_routing "/songs/example-song-42", controller: "songs", action: "show", slug: "example-song-42"
    assert_routing(
      { method: "post", path: "/songs/example-song-42/load" },
      controller: "songs",
      action: "load",
      slug: "example-song-42"
    )
  end

  test "eligible metadata page is useful and contains no lyrics" do
    song = create_song
    Lyric.create!(song: song, title: song.title, artist: song.artist, lyrics: "SECRET LYRIC MARKER")

    get "/songs/#{song.slug}"

    assert_response :success
    assert_select "title", "Print The Kiss Lyrics by Judee Sill | PrintLyrics"
    assert_select "meta[name='robots'][content*='index, follow']", 1
    assert_select "link[rel='canonical'][href='#{request.base_url}/songs/#{song.slug}']", 1
    assert_select "nav[aria-label='Breadcrumb'] a[href='/songs']", text: "Songs"
    assert_select "h1", "The Kiss"
    assert_select "[data-song-artist]", "Judee Sill"
    assert_select "main", /Heart Food/
    assert_select "form[action='/songs/#{song.slug}/load'][method='post'][data-controller='song-load']", count: 1 do
      assert_select "[data-song-load-target='idleLabel']", text: "Load lyrics to print"
      assert_select "[data-song-load-target='busyLabel']", text: /Loading/
    end
    assert_select "script[type='application/ld+json']", /MusicRecording/
    assert_no_match "SECRET LYRIC MARKER", response.body
  end

  test "song get never calls the lyric source" do
    song = create_song
    client = Object.new
    client.define_singleton_method(:find) { |_| raise "GET must not call LRCLIB" }

    with_lrc_lib_client(client) do
      get "/songs/#{song.slug}"
    end

    assert_response :success
  end

  test "load refreshes metadata and renders editable lyrics without persistence" do
    song = create_song(title: "Old title", artist: "Old artist")
    original_slug = song.slug
    result = build_result
    client = Object.new
    client.define_singleton_method(:find) { |_| result }

    assert_no_difference("Lyric.count") do
      with_lrc_lib_client(client) do
        post "/songs/#{song.slug}/load"
      end
    end

    assert_response :success
    assert_select "textarea[name='lyric[lyrics]']", /Love, rising/
    assert_select "input[name='catalog_token']", count: 1
    assert_select "form[action='#{lyrics_path}']", count: 1
    song.reload
    assert_equal "The Kiss", song.title
    assert_equal "Judee Sill", song.artist
    assert_equal original_slug, song.slug
    assert song.last_verified_at
  end

  test "confirmed not found demotes song and serves gone page" do
    song = create_song
    client = Object.new
    client.define_singleton_method(:find) { |_| raise LrcLibClient::NotFoundError }

    with_lrc_lib_client(client) do
      post "/songs/#{song.slug}/load"
    end

    assert_response :gone
    assert song.reload.unavailable_at
    assert_select "meta[name='robots'][content*='noindex']", 1

    get "/songs/#{song.slug}"
    assert_response :gone
  end

  test "transient source failure preserves eligibility and offers retry" do
    song = create_song
    client = Object.new
    client.define_singleton_method(:find) { |_| raise LrcLibClient::ServiceError }

    with_lrc_lib_client(client) do
      post "/songs/#{song.slug}/load"
    end

    assert_response :service_unavailable
    assert song.reload.indexable?
    assert_select "[role='alert']", /temporarily unavailable/i
    assert_select "form[action='/songs/#{song.slug}/load']", count: 1
    assert_select "a[href='/']", text: /search manually/i
  end

  test "empty catalog explains demand-led pages without pagination" do
    get "/songs"

    assert_response :success
    assert_select "h1", "Songs ready to print"
    assert_select "[data-empty-catalog]", /No songs are available yet/i
    assert_select "a[href='/']", text: /find a song/i
    assert_select "[aria-label='Song pages']", count: 0
  end

  test "catalog leads with ranked Apple songs and keeps them out of the archive" do
    refreshed_at = Time.zone.parse("2026-08-04 09:00:00")
    popular = create_song(
      source_id: 7,
      title: "Current Song",
      artist: "Current Artist",
      popular_rank: 1,
      popular_refreshed_at: refreshed_at,
      apple_music_id: "apple-7",
      apple_music_url: "https://music.apple.com/us/album/current-song/7"
    )
    archived = create_song(source_id: 8, title: "Archive Song", artist: "Archive Artist")

    get "/songs"

    assert_response :success
    assert_select "[data-popular-songs] h2", "Popular Now"
    assert_select "[data-popular-song]", count: 1 do
      assert_select "a[href='#{song_path(popular, entry: "popular")}']", text: /Current Song/
      assert_select "a[href='#{popular.apple_music_url}'][aria-label*='Apple Music']", count: 1
    end
    assert_select "time[datetime='2026-08-04']", text: /August 04, 2026/
    assert_select "[data-archive-song]", count: 1 do
      assert_select "a[href='#{song_path(archived, entry: "archive")}']", text: /Archive Song/
    end
    assert_select "[data-archive-song]", text: /Current Song/, count: 0
  end

  test "browse paginates eligible songs with crawlable links" do
    popular = create_song(
      source_id: 200,
      title: "Popular",
      artist: "Chart",
      popular_rank: 1,
      popular_refreshed_at: Time.current,
      apple_music_id: "apple-200",
      apple_music_url: "https://music.apple.com/us/album/popular/200"
    )
    51.times do |number|
      create_song(
        source_id: number + 1,
        title: "Song #{number.to_s.rjust(2, "0")}",
        artist: "Artist"
      )
    end
    unavailable = create_song(source_id: 100, title: "Unavailable", unavailable_at: Time.current)

    get "/songs"

    assert_response :success
    assert_select "[data-popular-song]", count: 1
    assert_select "[data-archive-song]", count: 50
    assert_select "link[rel='canonical'][href='#{request.base_url}/songs']", 1
    assert_select "a[rel='next'][href='/songs?page=2']", count: 1
    assert_no_match unavailable.title, response.body

    get "/songs?page=2"

    assert_response :success
    assert_select "[data-popular-songs]", count: 0
    assert_select "[data-archive-song]", count: 1
    assert_select "a[href='#{song_path(popular, entry: "popular")}']", count: 0
    assert_select "link[rel='canonical']", count: 1 do |elements|
      assert_equal songs_url(page: 2), elements.first["href"]
    end
    assert_select "a[rel='prev'][href='/songs']", count: 1
  end

  private

  def create_song(source_id: 42, title: "The Kiss", artist: "Judee Sill", unavailable_at: nil, **attributes)
    Song.create!(
      source_id: source_id,
      title: title,
      artist: artist,
      album: "Heart Food",
      duration_seconds: 214,
      indexable_at: 1.day.ago,
      last_verified_at: 1.day.ago,
      unavailable_at: unavailable_at,
      **attributes
    )
  end

  def build_result
    LrcLibResult.new(
      id: 42,
      title: "The Kiss",
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: "Love, rising",
      synced_lyrics: nil,
      instrumental: false
    )
  end

  def with_lrc_lib_client(client)
    SongsController.alias_method :__original_lrc_lib_client, :lrc_lib_client
    SongsController.define_method(:lrc_lib_client) { client }
    yield
  ensure
    SongsController.alias_method :lrc_lib_client, :__original_lrc_lib_client
    SongsController.remove_method :__original_lrc_lib_client
  end
end
