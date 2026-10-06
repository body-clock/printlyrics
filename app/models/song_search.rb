class SongSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  # How long a visitor waits while the ladder climbs. Each attempt is another
  # round trip to a source that may be slow or busy, and the first attempt has
  # already asked the question, so the budget bounds the stacking rather than
  # the single request's own timeout.
  DEADLINE_SECONDS = 5.0

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

    song_query.attempts.each_with_index do |attempt, index|
      break if index.positive? && clock.call >= expires_at

      rows = request(client, attempt)
      next if rows.empty?

      accepted = song_query.rank(rows.select { |row| song_query.accepts?([ row ]) })
      return accepted.first(LrcLibClient::SEARCH_LIMIT) if accepted.any?
    end

    []
  end

  def request(client, attempt)
    case attempt.kind
    when :fields
      client.search_by_fields(**attempt.params)
    else
      client.search(attempt.params[:q])
    end
  end
end
