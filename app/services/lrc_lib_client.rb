class LrcLibClient
  class Error < StandardError; end
  class NotFoundError < Error; end

  # Carries what the operator needs to tell a source outage from a bug in this
  # app. The message never includes the visitor's query: `/api/search` keeps it
  # in params, and the endpoint is the only part of the request recorded here.
  class ServiceError < Error
    attr_reader :endpoint, :status, :detail, :attempts

    def initialize(message = nil, endpoint: nil, status: nil, detail: nil, attempts: nil)
      @endpoint = endpoint
      @status = status
      @detail = detail
      @attempts = attempts
      super(message || "LRCLIB request failed")
    end
  end

  # LRCLIB asks clients to honor Retry-After: the edge answers 429 when a client
  # overruns the rate limit and 5xx (including the edge's 502 and 504) while the
  # source is busy. Its overload response is `ServerOverloaded`, which its own
  # body asks the client to retry after a moment. Two retries keep a source that
  # is momentarily busy from costing the visitor their search or their selection.
  RETRYABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze
  MAX_ATTEMPTS = 3
  DEFAULT_RETRY_WAIT = 1.0
  MAX_RETRY_WAIT = 2.0
  # A hung source is not worth stacking three full timeouts for: after this long
  # the visitor gets the fallback instead of a spinner.
  RETRY_BUDGET_SECONDS = 8.0

  DEFAULT_CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

  def initialize(connection: nil, sleeper: nil, clock: nil)
    @sleeper = sleeper || ->(seconds) { sleep(seconds) }
    @clock = clock || DEFAULT_CLOCK
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

  # `retries` is true for callers with no alternative to offer. The search
  # ladder passes false for every attempt: its attempts are alternatives to one
  # another, and a busy source is better answered by trying the next one than by
  # spending the visitor's wait on the same query again. `timeout` bounds this
  # request to the time the caller has left, so a hung source cannot outlast the
  # ladder's own budget.
  def search(query, retries: true, timeout: nil)
    build_results(request_json("/api/search", { q: query }, retries: retries, timeout: timeout))
  end

  # LRCLIB matches a separated title and artist more precisely than one keyword
  # string, so a query the visitor already split is asked this way.
  def search_by_fields(track_name:, artist_name:, retries: true, timeout: nil)
    build_results(
      request_json("/api/search", { track_name: track_name, artist_name: artist_name }, retries: retries, timeout: timeout)
    )
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
    unless rows.is_a?(Array)
      raise ServiceError.new("LRCLIB search answered with #{rows.class} instead of a list", endpoint: "/api/search")
    end

    # Every printable candidate is kept: the source's order is not a relevance
    # order, so the caller scores the whole set before it takes the handful it
    # shows.
    rows
      .filter_map { |row| build_result(row) }
      .select(&:printable?)
      .uniq(&:deduplication_key)
  end

  def request_json(path, params = {}, not_found: false, retries: true, timeout: nil)
    attempts = 0
    started_at = @clock.call
    max_attempts = retries ? MAX_ATTEMPTS : 1

    loop do
      attempts += 1
      response = @connection.get(path, params) do |request|
        request.options.timeout = timeout if timeout
      end
      raise NotFoundError if not_found && response.status == 404

      if retryable?(response.status, attempts, started_at, max_attempts)
        @sleeper.call(retry_wait(response))
        next
      end

      raise service_error(path, attempts, started_at, response: response) unless response.success?

      return JSON.parse(response.body)
    end
  rescue JSON::ParserError, Faraday::Error, SocketError, SystemCallError => error
    raise service_error(path, attempts, started_at, error: error)
  end

  def retryable?(status, attempts, started_at, max_attempts)
    attempts < max_attempts &&
      RETRYABLE_STATUSES.include?(status) &&
      @clock.call - started_at < RETRY_BUDGET_SECONDS
  end

  # The header is the source's own instruction; without one, wait long enough
  # for a busy server to matter and short enough that the visitor keeps waiting.
  def retry_wait(response)
    seconds = response.headers.to_h["Retry-After"].to_f
    return DEFAULT_RETRY_WAIT unless seconds.positive?

    [ seconds, MAX_RETRY_WAIT ].min
  end

  def service_error(path, attempts, started_at, response: nil, error: nil)
    status = response&.status
    detail = response && failure_detail(response.body)
    elapsed = (@clock.call - started_at).round(2)
    summary =
      if error
        "LRCLIB request to #{path} failed with #{error.class} after #{attempts} #{"attempt".pluralize(attempts)} in #{elapsed}s"
      else
        "LRCLIB answered #{status} for #{path} after #{attempts} #{"attempt".pluralize(attempts)} in #{elapsed}s"
      end
    summary += " (#{detail})" if detail.present?

    ServiceError.new(summary, endpoint: path, status: status, detail: detail, attempts: attempts)
  end

  # LRCLIB explains its own overload in the body; keep that phrase for the
  # operator and discard everything else it sent.
  def failure_detail(body)
    parsed = JSON.parse(body.to_s)
    return unless parsed.is_a?(Hash)

    [ parsed["name"], parsed["message"] ].compact_blank.join(": ").presence
  rescue JSON::ParserError
    nil
  end

  def build_result(row)
    LrcLibResult.from_api(row)
  end
end
