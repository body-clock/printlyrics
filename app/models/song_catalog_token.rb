class SongCatalogToken
  PURPOSE = "song-catalog-promotion"
  EXPIRY = 30.minutes

  def self.issue(result)
    verifier.generate(
      {
        source_id: result.id,
        title: result.title,
        artist: result.artist,
        album: result.album.presence,
        duration_seconds: result.duration.round
      },
      purpose: PURPOSE,
      expires_in: EXPIRY
    )
  end

  def self.verify(token)
    return if token.blank?

    verifier.verify(token, purpose: PURPOSE).symbolize_keys
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.verifier
    Rails.application.message_verifier(:song_catalog)
  end
  private_class_method :verifier
end
