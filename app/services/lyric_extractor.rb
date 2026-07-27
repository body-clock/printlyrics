class LyricExtractor
  Extraction = Data.define(:title, :artist, :lyrics)

  class Error < StandardError; end
  class UnsupportedSiteError < Error; end
  class FetchError < Error; end
  class ParseError < Error; end

  PARSERS = {
    "genius.com" => LyricExtractors::Genius,
    "www.genius.com" => LyricExtractors::Genius,
    "azlyrics.com" => LyricExtractors::AzLyrics,
    "www.azlyrics.com" => LyricExtractors::AzLyrics
  }.freeze

  def initialize(connection: nil)
    @connection = connection || Faraday.new(
      headers: { "User-Agent" => "PrintLyrics/1.0 (+https://printlyrics.app)" }
    ) do |faraday|
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
      faraday.adapter Faraday.default_adapter
    end
  end

  def extract(url)
    uri = parse_uri(url)
    parser = PARSERS[uri.host.downcase]
    raise UnsupportedSiteError unless parser

    response = @connection.get(uri.to_s)
    raise FetchError unless response.success?

    parser.new.parse(response.body)
  rescue Faraday::Error, SocketError, SystemCallError
    raise FetchError
  end

  private

  def parse_uri(url)
    uri = URI.parse(url.to_s.strip)
    raise UnsupportedSiteError unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri
  rescue URI::InvalidURIError
    raise UnsupportedSiteError
  end
end
