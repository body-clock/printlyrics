class PopularSongMatcher
  def self.catalog_key(title, artist)
    [ normalize(title), normalize_artist(artist) ]
  end

  def self.normalize(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .downcase
      .gsub(/[^\p{Alnum}]+/u, " ")
      .squish
  end

  def self.normalize_artist(value)
    normalize(value).delete_prefix("the ")
  end

  def initialize(client:)
    @client = client
  end

  def match(candidate)
    matches = @client
      .search_catalog("#{candidate.title} #{candidate.artist}")
      .select { |result| equivalent?(candidate, result) }

    matches.one? ? matches.first : nil
  end

  private

  def equivalent?(candidate, result)
    self.class.catalog_key(candidate.title, candidate.artist) ==
      self.class.catalog_key(result.title, result.artist)
  end
end
