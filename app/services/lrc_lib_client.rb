class LrcLibClient
  class Error < StandardError; end
  class NotFoundError < Error; end
  class ServiceError < Error; end

  SEARCH_LIMIT = 5

  # LRCLIB asks clients to honor Retry-After: the edge answers 429 when a client
  # overruns the rate limit and 503 while the server is busy. One retry keeps a
  # momentarily busy source from costing the visitor their search.
  RETRYABLE_STATUSES = [ 429, 500, 503 ].freeze
  DEFAULT_RETRY_WAIT = 1.0
  MAX_RETRY_WAIT = 2.0

  def initialize(connection: nil, sleeper: nil)
    @sleeper = sleeper || ->(seconds) { sleep(seconds) }
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
    build_results(request_json("/api/search", { q: query }))
  end

  # LRCLIB matches a separated title and artist more precisely than one keyword
  # string, so a query the visitor already split is asked this way.
  def search_by_fields(track_name:, artist_name:)
    build_results(request_json("/api/search", { track_name: track_name, artist_name: artist_name }))
  end

  def find(id)
    id = Integer(id, exception: false)
    raise NotFoundError unless id&.positive?

    result = build_result(request_json("/api/get/#{id}", not_found: true))
    raise NotFoundError unless result&.printable?

    result
  end

  private

  def build_results(rows)
    raise ServiceError unless rows.is_a?(Array)

    rows
      .filter_map { |row| build_result(row) }
      .select(&:printable?)
      .uniq(&:deduplication_key)
      .first(SEARCH_LIMIT)
  end

  def request_json(path, params = {}, not_found: false)
    retried = false

    loop do
      response = @connection.get(path, params)
      raise NotFoundError if not_found && response.status == 404

      if !retried && RETRYABLE_STATUSES.include?(response.status)
        retried = true
        @sleeper.call(retry_wait(response))
        next
      end

      raise ServiceError unless response.success?

      return JSON.parse(response.body)
    end
  rescue JSON::ParserError, Faraday::Error, SocketError, SystemCallError
    raise ServiceError
  end

  # The header is the source's own instruction; without one, wait long enough
  # for a busy server to matter and short enough that the visitor keeps waiting.
  def retry_wait(response)
    seconds = response.headers.to_h["Retry-After"].to_f
    return DEFAULT_RETRY_WAIT unless seconds.positive?

    [ seconds, MAX_RETRY_WAIT ].min
  end

  def build_result(row)
    LrcLibResult.from_api(row)
  end
end
