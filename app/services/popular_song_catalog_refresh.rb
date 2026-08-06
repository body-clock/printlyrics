require "set"

class PopularSongCatalogRefresh
  class RefreshError < StandardError; end

  MAX_PUBLISHED = 20

  def initialize(apple_client:, matcher:, clock: -> { Time.current })
    @apple_client = apple_client
    @matcher = matcher
    @clock = clock
  end

  def call
    candidates = @apple_client.fetch.uniq(&:id).first(25)
    matches = collect_matches(candidates)
    raise RefreshError, "no confident lyric matches" if matches.empty?

    publish(matches)
    {
      candidates: candidates.size,
      matched: matches.size,
      skipped: candidates.size - matches.size,
      published: matches.size
    }
  rescue AppleTopSongsClient::ServiceError, LrcLibClient::ServiceError,
         ActiveRecord::ActiveRecordError => error
    raise RefreshError, error.message
  end

  private

  def collect_matches(candidates)
    source_ids = Set.new

    candidates.filter_map do |candidate|
      result = @matcher.match(candidate)
      next unless result && source_ids.add?(result.id)

      [ candidate, result ]
    end.first(MAX_PUBLISHED)
  end

  def publish(matches)
    refreshed_at = @clock.call

    Song.transaction do
      existing_by_catalog_key = Song.indexable.index_by do |song|
        PopularSongMatcher.catalog_key(song.title, song.artist)
      end
      Song.where.not(popular_rank: nil).update_all(popular_rank: nil, popular_refreshed_at: nil)

      matches.each.with_index(1) do |(candidate, result), rank|
        song = find_or_initialize_song(result, existing_by_catalog_key)
        song.assign_attributes(source_metadata(result, song, refreshed_at)) if song.source_id == result.id
        song.assign_attributes(
          apple_music_id: candidate.id,
          apple_music_url: candidate.url,
          popular_rank: rank,
          popular_refreshed_at: refreshed_at
        )
        song.save!
      end
    end
  end

  def find_or_initialize_song(result, existing_by_catalog_key)
    Song.find_by(source_id: result.id) ||
      existing_by_catalog_key[PopularSongMatcher.catalog_key(result.title, result.artist)] ||
      Song.new(source_id: result.id)
  end

  def source_metadata(result, song, refreshed_at)
    {
      title: result.title,
      artist: result.artist,
      album: result.album.presence,
      duration_seconds: result.duration.round,
      indexable_at: song.indexable_at || refreshed_at,
      unavailable_at: nil,
      last_verified_at: refreshed_at
    }
  end
end
