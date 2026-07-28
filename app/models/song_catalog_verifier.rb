class SongCatalogVerifier
  def initialize(client:)
    @client = client
  end

  def verify(limit: 100)
    result = { checked: 0, available: 0, unavailable: 0, failed: 0 }

    candidates(limit).each do |song|
      result[:checked] += 1
      verify_song(song, result)
    end

    result
  end

  private

  def candidates(limit)
    Song
      .where.not(indexable_at: nil)
      .order(Arel.sql("last_verified_at IS NOT NULL, last_verified_at ASC"))
      .limit([ limit.to_i, 0 ].max)
  end

  def verify_song(song, result)
    source_result = @client.find(song.source_id)
    song.refresh_from_result!(source_result)
    result[:available] += 1
  rescue LrcLibClient::NotFoundError
    song.mark_unavailable!
    result[:unavailable] += 1
  rescue LrcLibClient::ServiceError
    song.update_column(:last_verified_at, Time.current)
    result[:failed] += 1
  end
end
