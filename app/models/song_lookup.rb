class SongLookup
  attr_reader :lyric, :catalog_token, :result, :error, :http_status

  def perform(result_id, client:)
    result = client.find(result_id)
    @result = result
    @lyric = Lyric.new(
      title: result.title,
      artist: result.artist,
      lyrics: result.lyrics,
      source_url: result.source_url
    )
    @catalog_token = SongCatalogToken.issue(result)
    @http_status = :ok
    :ok
  rescue LrcLibClient::NotFoundError
    @error = I18n.t("songs.errors.unavailable")
    @http_status = :unprocessable_content
    nil
  rescue LrcLibClient::ServiceError
    @error = I18n.t("songs.errors.service")
    @http_status = :service_unavailable
    nil
  end

  def success?
    @lyric.present? && @error.nil?
  end
end
