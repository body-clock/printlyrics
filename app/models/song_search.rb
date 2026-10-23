class SongSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  # How long a visitor waits while the ladder climbs. Each attempt is another
  # round trip to a source that may be slow or busy, and the first attempt has
  # already asked the question, so the budget bounds the stacking rather than
  # the single request's own timeout.
  DEADLINE_SECONDS = 5.0

  # The source answers one search with up to twenty records; the panel shows
  # five. The cap applies after scoring, so the closest records are the ones
  # that survive rather than the source's first five.
  RESULT_LIMIT = 5

  DEFAULT_CLOCK = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

  attribute :query, :string

  validates :query, presence: true
  validates :query, length: { maximum: 200 }

  attr_reader :results

  # Raises LrcLibClient::ServiceError when the source is unavailable. Callers
  # translate that into user copy and an HTTP status. Tests inject a clock to
  # drive the deadline without waiting.
  def perform(client:, clock: nil)
    return false unless valid?

    @results = find_results(client, clock || DEFAULT_CLOCK)
    true
  end

  def empty?
    results&.empty?
  end

  private

  # Walks the query's attempts from precise to broad and stops at the first one
  # that answers, so a query the source can match costs a single request.
  #
  # Every row is scored against the visitor's own words before it is shown,
  # whichever attempt produced it: LRCLIB answers some exact queries with an
  # unrelated record, and a wrong sheet is worse than no sheet. A tier whose
  # rows all fail scoring is skipped rather than answered with.
  def find_results(client, clock)
    song_query = SongQuery.new(query)
    expires_at = clock.call + DEADLINE_SECONDS
    failure = nil

    song_query.attempts.each_with_index do |attempt, index|
      remaining = expires_at - clock.call
      break if index.positive? && remaining <= 0

      begin
        # No attempt is retried here. The ladder is a list of alternatives, so
        # a busy source is better answered by asking the next one than by
        # spending the visitor's wait on the same query again; a source that
        # refuses one request usually refuses the retries too. The client keeps
        # its retries for callers that have no alternative to offer.
        rows = request(client, attempt, remaining: remaining)
      rescue LrcLibClient::ServiceError => error
        # A 429 is the client's own rate limit, not this query's answer: asking
        # the other attempts would be refused too and would extend the block.
        raise if error.status == 429

        failure = error
        next
      end

      next if rows.empty?

      accepted = song_query.rank(rows.select { |row| song_query.accepts?([ row ]) })
      return accepted.first(RESULT_LIMIT) if accepted.any?
    end

    # A failure on a broad attempt must not hide a later hit, but a search that
    # produced no result is still an outage rather than a miss: the caller has
    # to tell the visitor the source failed, not that the song does not exist.
    raise failure if failure

    []
  end

  def request(client, attempt, remaining:)
    # The budget is checked between attempts, but a single request can outlast
    # it: the client's own read timeout is longer than the ladder's deadline.
    # Passing what is left makes the deadline the visitor sees true. An attempt
    # that still runs with no time left (only the first can) gets the full
    # budget rather than an unusable sliver.
    timeout = remaining.positive? ? remaining : DEADLINE_SECONDS

    case attempt.kind
    when :fields
      client.search_by_fields(**attempt.params, retries: false, timeout: timeout)
    else
      client.search(attempt.params[:q], retries: false, timeout: timeout)
    end
  end
end
