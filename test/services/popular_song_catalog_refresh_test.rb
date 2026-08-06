require "test_helper"

class PopularSongCatalogRefreshTest < ActiveSupport::TestCase
  test "publishes matches in source order and preserves departed pages" do
    departed = Song.create!(source_id: 99, title: "Old", artist: "Artist", indexable_at: 2.days.ago, popular_rank: 1, popular_refreshed_at: 1.week.ago)
    candidates = 3.times.map { |index| apple_candidate(index + 1) }
    matches = { "1" => result(11), "3" => result(33) }
    refreshed_at = Time.zone.parse("2026-08-05 12:00:00")

    outcome = PopularSongCatalogRefresh.new(
      apple_client: fake_apple_client(candidates),
      matcher: fake_matcher(matches),
      clock: -> { refreshed_at }
    ).call

    assert_equal({ candidates: 3, matched: 2, skipped: 1, published: 2 }, outcome)
    assert_equal [ 11, 33 ], Song.popular.pluck(:source_id)
    assert departed.reload.indexable?
    assert_nil departed.popular_rank
    assert_equal refreshed_at, Song.popular.pick(:popular_refreshed_at)
  end

  test "is idempotent and keeps stable source id slugs" do
    candidate = apple_candidate(1)
    refresh = PopularSongCatalogRefresh.new(apple_client: fake_apple_client([ candidate ]), matcher: fake_matcher("1" => result(11)))

    refresh.call
    slug = Song.find_by!(source_id: 11).slug
    assert_no_difference("Song.count") { refresh.call }
    assert_equal slug, Song.find_by!(source_id: 11).slug
  end

  test "reuses an eligible title and artist page instead of creating a duplicate source page" do
    existing = Song.create!(source_id: 99, title: "Song!", artist: "The Artist", indexable_at: 2.days.ago)

    assert_no_difference("Song.count") do
      PopularSongCatalogRefresh.new(
        apple_client: fake_apple_client([ apple_candidate(1) ]),
        matcher: fake_matcher("1" => result(11))
      ).call
    end

    assert_equal 1, existing.reload.popular_rank
    assert_equal 99, existing.source_id
  end

  test "preserves the prior snapshot on provider failure or zero matches" do
    existing = Song.create!(source_id: 99, title: "Old", artist: "Artist", indexable_at: 2.days.ago, popular_rank: 1, popular_refreshed_at: 1.week.ago)
    previous_refresh = existing.popular_refreshed_at

    assert_raises(PopularSongCatalogRefresh::RefreshError) do
      PopularSongCatalogRefresh.new(apple_client: fake_apple_client([ apple_candidate(1) ]), matcher: fake_matcher({})).call
    end

    assert_equal 1, existing.reload.popular_rank
    assert_equal previous_refresh, existing.popular_refreshed_at
  end

  test "rolls back the snapshot when matched metadata cannot be persisted" do
    existing = Song.create!(source_id: 99, title: "Old", artist: "Artist", indexable_at: 2.days.ago, popular_rank: 1, popular_refreshed_at: 1.week.ago)
    invalid_result = result(11)
    invalid_result.instance_variable_set(:@title, "x" * 201)

    assert_raises(PopularSongCatalogRefresh::RefreshError) do
      PopularSongCatalogRefresh.new(
        apple_client: fake_apple_client([ apple_candidate(1) ]),
        matcher: fake_matcher("1" => invalid_result)
      ).call
    end

    assert_equal 1, existing.reload.popular_rank
  end

  private

  def fake_apple_client(candidates)
    Object.new.tap { |client| client.define_singleton_method(:fetch) { candidates } }
  end

  def fake_matcher(matches)
    Object.new.tap { |matcher| matcher.define_singleton_method(:match) { |candidate| matches[candidate.id] } }
  end

  def apple_candidate(number)
    AppleSongCandidate.new(id: number.to_s, title: "Song #{number}", artist: "Artist", url: "https://music.apple.com/us/album/song/#{number}")
  end

  def result(id)
    LrcLibResult.new(id: id, title: "Song", artist: "Artist", album: "Album", duration: 120, plain_lyrics: "Lyrics", synced_lyrics: nil, instrumental: false)
  end
end
