class SongLookup
  attr_reader :lyric, :error, :http_status

  def perform(result_id, client:)
    result = client.find(result_id)
    @lyric = Lyric.new(
      title: result.title,
      artist: result.artist,
      lyrics: result.lyrics,
      source_url: result.source_url
    )
    @http_status = :ok
    :ok
  rescue LrcLibClient::NotFoundError
    @error = "That song is no longer available"
    @http_status = :unprocessable_content
    nil
  rescue LrcLibClient::ServiceError
    @error = "Song search is temporarily unavailable. You can still paste lyrics below."
    @http_status = :service_unavailable
    nil
  end

  def success?
    @lyric.present? && @error.nil?
  end
end
