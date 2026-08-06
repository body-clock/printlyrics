class AppleTopSongsClient
  class ServiceError < StandardError; end

  FEED_PATH = "/api/v2/us/music/most-played/25/songs.json"

  def initialize(connection: nil)
    @connection = connection || Faraday.new(
      url: "https://rss.marketingtools.apple.com",
      headers: {
        "Accept" => "application/json",
        "User-Agent" => "PrintLyrics/1.0 (+https://printlyrics.app)"
      }
    ) do |faraday|
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
      faraday.adapter Faraday.default_adapter
    end
  end

  def fetch
    response = @connection.get(FEED_PATH)
    raise ServiceError unless response.success?

    payload = JSON.parse(response.body)
    raise ServiceError unless payload.is_a?(Hash)

    rows = payload.dig("feed", "results")
    raise ServiceError unless rows.is_a?(Array) && rows.any? && rows.size <= 25

    rows.map { |row| AppleSongCandidate.from_api(row) }
  rescue JSON::ParserError, AppleSongCandidate::InvalidError,
         Faraday::Error, SocketError, SystemCallError
    raise ServiceError
  end
end
