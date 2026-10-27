class LrcLibClient
  class Error < StandardError; end
  class NotFoundError < Error; end

  # Carries what the operator needs to tell a source outage from a bug in this
  # app. The message never includes the visitor's query: `/api/search` keeps it
  # in params, and the endpoint is the only part of the request recorded here.
  class ServiceError < Error
    # A source that is busy, rate limiting, or unreachable is an operational
    # condition this app already answers with fallback copy. A parse failure, a
    # payload the client cannot read, or a status it never retried is a defect.
    UNAVAILABLE_CAUSES = [ Faraday::Error, SocketError, SystemCallError ].freeze

    attr_reader :endpoint, :status, :detail, :attempts

    def initialize(message = nil, endpoint: nil, status: nil, detail: nil, attempts: nil, cause: nil)
      @endpoint = endpoint
      @status = status
      @detail = detail
      @attempts = attempts
      @cause = cause
      super(message || "LRCLIB request failed")
    end

    # A source that answers with a server error or a rate limit owns the
    # failure even when the client chose not to retry that status: the visitor
    # still gets fallback copy, and the operator still needs an outage signal
    # rather than a fault nobody can act on.
    def source_unavailable?
      return status == 429 || status >= 500 if status

      UNAVAILABLE_CAUSES.any? { |klass| @cause.is_a?(klass) }
    end
  end

  # LRCLIB asks clients to honor Retry-After: the edge answers 429 when a client
  # overruns the rate limit and 5xx (including the edge's 502 and 504) while the
  # source is busy. Its overload response is `ServerOverloaded`, which its own
  # body asks the client to retry after a moment. Two retries keep a source that
  # is momentarily busy from costing the visitor their search or their selection.
  RETRYABLE_STATUSES = [ 429, 500, 502, 503, 504 ].freeze
  MAX_ATTEMPTS = 3
  # A short first wait leaves room in the visitor's budget for the answer a
  # busy source gives after it recovers; doubling covers a slightly longer
  # overload without ever spending the whole budget on one wait.
  DEFAULT_RETRY_WAIT = 0.5
  MAX_RETRY_WAIT = 2.0
  # A retry with less than this left cannot be sent and answered before the
  # budget ends. Failing at that point is faster for the visitor and one request
  # lighter for the source.
  MIN_RETRY_WINDOW = 0.5
  # A hung source is not worth stacking three full timeouts for: after this long
  # the visitor gets the fallback instead of a spinner. A caller can pass its
  # own `timeout`, which becomes the budget for the whole call, retries included.
  RETRY_BUDGET_SECONDS = 8.0
  OPEN_TIMEOUT = 5.0

  # LRCLIB is a shared community source, and a song site's traffic repeats: the
  # same title, the same miss, the same song picked again. An answer it already
  # gave is kept for the next visitor, so a repeat costs the source nothing and
  # a cached song still works while the source is unavailable. An empty answer
  # is kept only long enough to absorb a retry, never to hide a new record.
  # Every answered search and selection also keeps a stale copy: when the source
  # is unavailable after its freshness window, the last answer it gave is still
  # more useful than an outage page.
  CACHE_TTL = 1.hour
  EMPTY_CACHE_TTL = 5.minutes
  STALE_CACHE_TTL = 1.week

  DEFAULT_CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
  # Retries from every visitor must not line up on the same instant, or a busy
  # source receives the same burst again. Spread the wait below the computed
  # backoff; a Retry-After header is still honored exactly.
  DEFAULT_JITTER = ->(seconds) { seconds * (0.5 + rand * 0.5) }

  def initialize(connection: nil, sleeper: nil, clock: nil, cache: nil, jitter: nil)
    @sleeper = sleeper || ->(seconds) { sleep(seconds) }
    @clock = clock || DEFAULT_CLOCK
    @cache = cache || Rails.cache
    @jitter = jitter || DEFAULT_JITTER
    @connection = connection || Faraday.new(
      url: "https://lrclib.net",
      headers: {
        "Accept" => "application/json",
        "User-Agent" => "PrintLyrics/1.0 (+https://printlyrics.app)"
      }
    ) do |faraday|
      faraday.options.timeout = RETRY_BUDGET_SECONDS
      faraday.options.open_timeout = OPEN_TIMEOUT
      faraday.adapter Faraday.default_adapter
    end
  end

  # `timeout` is the budget for the whole call, retries and their waits
  # included, so a hung source cannot outlast the wait the caller promised the
  # visitor. The search ladder passes the time it has left, which lets a busy
  # source recover on a retry without making the ladder itself overrun.
  def search(query, retries: true, timeout: nil)
    params = { q: query }
    cached_results(params) do
      build_results(request_json("/api/search", params, retries: retries, timeout: timeout))
    end
  end

  # LRCLIB matches a separated title and artist more precisely than one keyword
  # string, so a query the visitor already split is asked this way.
  def search_by_fields(track_name:, artist_name:, retries: true, timeout: nil)
    params = { track_name: track_name, artist_name: artist_name }
    cached_results(params) do
      build_results(request_json("/api/search", params, retries: retries, timeout: timeout))
    end
  end

  def find(id)
    id = Integer(id, exception: false)
    raise NotFoundError unless id&.positive?

    cached_result(id) do
      result = build_result(request_json("/api/get/#{id}", not_found: true))
      raise NotFoundError unless result&.printable?

      result
    end
  end

  private

  # A query is hashed so the cache keyspace never holds what the visitor typed,
  # and only an answer the source gave is kept: a timeout or an outage is asked
  # again rather than remembered. A stale copy outlives the fresh one and is
  # served only when the source cannot answer, so an outage falls back to what
  # LRCLIB last said instead of to an error page.
  def cached_results(params)
    key = [ "lrc_lib", "search", ActiveSupport::Digest.hexdigest(JSON.generate(params)) ]
    stored = @cache.read(key)
    return deserialize_results(stored) if stored

    results = yield
    attributes = results.map(&:cache_attributes)
    @cache.write(key, attributes, expires_in: results.empty? ? EMPTY_CACHE_TTL : CACHE_TTL)
    @cache.write(stale_key(key), attributes, expires_in: STALE_CACHE_TTL) if results.any?
    results
  rescue ServiceError => error
    raise unless error.source_unavailable?

    stored = @cache.read(stale_key(key))
    raise unless stored

    deserialize_results(stored)
  end

  def cached_result(id)
    key = [ "lrc_lib", "find", id ]
    stored = @cache.read(key)
    return LrcLibResult.new(**stored) if stored

    result = yield
    attributes = result.cache_attributes(lyrics: true)
    @cache.write(key, attributes, expires_in: CACHE_TTL)
    @cache.write(stale_key(key), attributes, expires_in: STALE_CACHE_TTL)
    result
  rescue ServiceError => error
    raise unless error.source_unavailable?

    stored = @cache.read(stale_key(key))
    raise unless stored

    LrcLibResult.new(**stored)
  end

  def stale_key(key) = [ *key, "stale" ]

  def deserialize_results(attributes)
    attributes.map { |stored| LrcLibResult.new(**stored) }
  end

  def build_results(rows)
    unless rows.is_a?(Array)
      raise ServiceError.new("LRCLIB search answered with #{rows.class} instead of a list", endpoint: "/api/search")
    end

    # Every printable candidate is kept: the source's order is not a relevance
    # order, so the caller scores the whole set before it takes the handful it
    # shows. Only its metadata leaves this method; the lyrics follow by id when
    # the visitor picks a row.
    rows
      .filter_map { |row| build_result(row) }
      .select(&:printable?)
      .uniq(&:deduplication_key)
      .map(&:metadata_only)
  end

  def request_json(path, params = {}, not_found: false, retries: true, timeout: nil)
    attempts = 0
    started_at = @clock.call
    budget = timeout || RETRY_BUDGET_SECONDS
    max_attempts = retries ? MAX_ATTEMPTS : 1

    loop do
      # The first attempt gets the whole budget; each retry gets what the
      # previous request and wait left. The floor keeps a retry that the
      # affordability check approved from being handed a timeout too small to
      # hear any answer.
      elapsed = attempts.zero? ? 0.0 : @clock.call - started_at
      request_timeout = [ budget - elapsed, MIN_RETRY_WINDOW ].max
      attempts += 1

      response = begin
        @connection.get(path, params) do |request|
          request.options.timeout = request_timeout
          request.options.open_timeout = [ request_timeout, OPEN_TIMEOUT ].min
        end
      rescue Faraday::Error, SocketError, SystemCallError => error
        wait = retry_wait(nil, attempts)
        if attempts < max_attempts && retry_window?(started_at, budget, wait)
          @sleeper.call(wait)
          next
        end

        raise service_error(path, attempts, started_at, error: error)
      end
      raise NotFoundError if not_found && response.status == 404

      if RETRYABLE_STATUSES.include?(response.status) && attempts < max_attempts
        wait = retry_wait(response, attempts)
        if retry_window?(started_at, budget, wait)
          @sleeper.call(wait)
          next
        end
      end

      raise service_error(path, attempts, started_at, response: response) unless response.success?

      return JSON.parse(response.body)
    end
  rescue JSON::ParserError => error
    raise service_error(path, attempts, started_at, error: error)
  end

  # A retry is worth sending only when another attempt fits inside the budget
  # after its wait. Measured after the answer arrived, not before, because a
  # slow response consumes the same budget as the wait.
  def retry_window?(started_at, budget, wait)
    budget - (@clock.call - started_at) - wait > MIN_RETRY_WINDOW
  end

  # The header is the source's own instruction; without one, back off by a
  # jittered exponential wait that is long enough for a busy server to matter
  # and short enough that the visitor keeps waiting.
  def retry_wait(response, attempts)
    seconds = response&.headers&.[]("Retry-After").to_f
    return [ seconds, MAX_RETRY_WAIT ].min if seconds.positive?

    backoff = DEFAULT_RETRY_WAIT * (2 ** (attempts - 1))
    @jitter.call([ backoff, MAX_RETRY_WAIT ].min)
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

    ServiceError.new(summary, endpoint: path, status: status, detail: detail, attempts: attempts, cause: error)
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
