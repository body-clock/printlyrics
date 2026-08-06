require "uri"

class AppleSongCandidate
  class InvalidError < StandardError; end

  ID_PATTERN = /\A[1-9]\d*\z/

  attr_reader :id, :title, :artist, :url

  def self.from_api(row)
    raise InvalidError unless row.is_a?(Hash)

    new(
      id: row["id"],
      title: row["name"],
      artist: row["artistName"],
      url: row["url"]
    )
  end

  def initialize(id:, title:, artist:, url:)
    @id = id.to_s.strip
    @title = title.to_s.strip
    @artist = artist.to_s.strip
    @url = url.to_s.strip

    raise InvalidError unless valid?
  end

  private

  def valid?
    return false unless id.match?(ID_PATTERN)
    return false if id.length > 100 || title.blank? || title.length > 200
    return false if artist.blank? || artist.length > 200 || url.length > 500

    uri = URI.parse(url)
    uri.scheme == "https" && uri.host == "music.apple.com" && [ nil, 443 ].include?(uri.port)
  rescue URI::InvalidURIError
    false
  end
end
