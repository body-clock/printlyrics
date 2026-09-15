class SongLookup
  attr_reader :lyric, :catalog_token, :result

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
  end
end
