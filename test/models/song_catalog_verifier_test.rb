require "test_helper"

class SongCatalogVerifierTest < ActiveSupport::TestCase
  test "success refreshes metadata and reactivates without changing slug" do
    song = create_song(
      source_id: 42,
      title: "Old title",
      unavailable_at: 1.day.ago,
      last_verified_at: 2.days.ago
    )
    original_slug = song.slug
    client = fake_client(42 => build_result(id: 42))

    result = SongCatalogVerifier.new(client: client).verify(limit: 10)

    song.reload
    assert_equal "The Kiss", song.title
    assert_equal "Judee Sill", song.artist
    assert_nil song.unavailable_at
    assert song.indexable?
    assert_equal original_slug, song.slug
    assert_equal({ checked: 1, available: 1, unavailable: 0, failed: 0 }, result)
  end

  test "heartbeat alone does not change material updated timestamp" do
    song = create_song(source_id: 42, last_verified_at: 2.days.ago)
    previous_updated_at = song.updated_at
    client = fake_client(42 => build_result(id: 42))

    travel 1.hour do
      SongCatalogVerifier.new(client: client).verify
    end

    song.reload
    assert_operator song.last_verified_at, :>, 2.days.ago
    assert_equal previous_updated_at, song.updated_at
  end

  test "not found demotes while transient failure preserves and continues" do
    missing = create_song(source_id: 1, title: "Missing", last_verified_at: 3.days.ago)
    failing = create_song(source_id: 2, title: "Failing", last_verified_at: 2.days.ago)
    available = create_song(source_id: 3, title: "Available", last_verified_at: 1.day.ago)
    client = fake_client(
      1 => LrcLibClient::NotFoundError,
      2 => LrcLibClient::ServiceError,
      3 => build_result(id: 3, title: "Available")
    )

    travel 1.hour do
      result = SongCatalogVerifier.new(client: client).verify(limit: 10)

      assert missing.reload.unavailable_at
      assert failing.reload.indexable?
      assert_operator failing.last_verified_at, :>, 2.days.ago
      assert available.reload.indexable?
      assert_equal({ checked: 3, available: 1, unavailable: 1, failed: 1 }, result)
    end
  end

  test "processes the least recently verified records up to the limit" do
    newest = create_song(source_id: 1, last_verified_at: 1.hour.ago)
    oldest = create_song(source_id: 2, last_verified_at: 3.days.ago)
    unverified = create_song(source_id: 3, last_verified_at: nil)
    seen = []
    client = Object.new
    client.define_singleton_method(:find) do |id|
      seen << id
      build = ->(song) do
        LrcLibResult.new(
          id: song.source_id,
          title: song.title,
          artist: song.artist,
          album: song.album,
          duration: song.duration_seconds,
          plain_lyrics: "Line",
          synced_lyrics: nil,
          instrumental: false
        )
      end
      build.call(Song.find_by!(source_id: id))
    end

    result = SongCatalogVerifier.new(client: client).verify(limit: 2)

    assert_equal [ unverified.source_id, oldest.source_id ], seen
    assert_equal 2, result[:checked]
    assert_equal 1.hour.ago.to_i, newest.reload.last_verified_at.to_i
  end

  private

  def create_song(source_id:, title: "The Kiss", unavailable_at: nil, last_verified_at:)
    Song.create!(
      source_id: source_id,
      title: title,
      artist: "Judee Sill",
      album: "Heart Food",
      duration_seconds: 214,
      indexable_at: 4.days.ago,
      unavailable_at: unavailable_at,
      last_verified_at: last_verified_at
    )
  end

  def build_result(id:, title: "The Kiss")
    LrcLibResult.new(
      id: id,
      title: title,
      artist: "Judee Sill",
      album: "Heart Food",
      duration: 214,
      plain_lyrics: "Line",
      synced_lyrics: nil,
      instrumental: false
    )
  end

  def fake_client(outcomes)
    Object.new.tap do |client|
      client.define_singleton_method(:find) do |id|
        outcome = outcomes.fetch(id)
        raise outcome if outcome.is_a?(Class) && outcome < Exception

        outcome
      end
    end
  end
end
