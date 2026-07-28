class LrcLibClient
  class Error < StandardError; end
  class NotFoundError < Error; end
  class ServiceError < Error; end

  SEARCH_LIMIT = 5

  def initialize(connection: nil)
    @connection = connection || Faraday.new(
      url: "https://lrclib.net",
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

  def search(query)
    rows = request_json("/api/search", { q: query })
    raise ServiceError unless rows.is_a?(Array)

    rows
      .filter_map { |row| build_result(row) }
      .select(&:printable?)
      .uniq(&:deduplication_key)
      .first(SEARCH_LIMIT)
  end

  def find(id)
    id = Integer(id, exception: false)
    raise NotFoundError unless id&.positive?

    result = build_result(request_json("/api/get/#{id}", not_found: true))
    raise NotFoundError unless result&.printable?

    result
  end

  private

  def request_json(path, params = {}, not_found: false)
    response = @connection.get(path, params)
    raise NotFoundError if not_found && response.status == 404
    raise ServiceError unless response.success?

    JSON.parse(response.body)
  rescue JSON::ParserError, Faraday::Error, SocketError, SystemCallError
    raise ServiceError
  end

  def build_result(row)
    LrcLibResult.from_api(row)
  end
end
