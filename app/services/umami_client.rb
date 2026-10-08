# Records a stored feedback submission in this site's own analytics service.
#
# Umami's /api/send takes events from a server as well as from the tracker, and
# it derives the visitor's session from the address and user agent the payload
# carries. Sending the visitor's own address and agent, rather than this
# container's, is what puts the event in the session their pageviews already
# created: Umami hashes both into the session id, and its session row is only
# ever inserted (createSession is an `on conflict do nothing`), so nothing this
# call sends can overwrite what the tracker recorded.
#
# Only Umami receives this. Plausible is a third party, and the dispatcher in
# lib/analytics.js reports to both destinations, so the payload below never
# travels through it.
#
# docs/measurement-contract.md owns the vocabulary and what may travel.
class UmamiClient
  class Error < StandardError; end

  # Raised when the event could not be recorded: no website is configured, or
  # the service refused it or did not answer. The caller keeps the submission,
  # which is already stored — analytics never blocks a product action.
  #
  # A clean return means Umami accepted the request, not that the row exists:
  # it answers 200 to a payload its own bot check drops, exactly as it does for
  # the tracker. Every real submission carries a browser's user agent, the same
  # one that already decides whether that visitor's pageviews are kept.
  class ServiceError < Error; end

  SEND_PATH = "/api/send"
  EVENT_NAME = "Feedback Submitted"

  # The page a submission reports, in the synthetic form the tracker uses. A
  # submission never reports the page it was written from, because on a saved
  # sheet that page is a share token: the sheet surface reports the same
  # `:token` location `analyticsUrl` redacts one to.
  SURFACE_PATHS = {
    "search_miss" => "/",
    "sheet" => "/lyrics/:token",
    "feedback_page" => "/feedback"
  }.freeze

  def initialize(connection: nil, origin: nil, website_id: nil)
    @origin = origin || Rails.configuration.x.umami_origin
    @website_id = website_id || Rails.configuration.x.umami_website_id
    @connection = connection || Faraday.new do |faraday|
      # The note is already stored by the time this runs, so the visitor is
      # waiting on a report about it rather than on the submission: the budget
      # is the shortest one that still covers a healthy answer.
      faraday.options.timeout = 3
      faraday.options.open_timeout = 2
      faraday.adapter Faraday.default_adapter
    end
  end

  # A host with no website id renders no tracker, and the test environment's
  # placeholder names no website either: neither has a destination to send to.
  def configured?
    @origin.present? && @website_id.present? &&
      @website_id != Rails.configuration.x.umami_placeholder_website_id
  end

  def record_feedback(feedback, ip: nil, user_agent: nil, hostname: nil)
    raise ServiceError, "Umami is not configured" unless configured?

    response = @connection.post("#{@origin}#{SEND_PATH}") do |request|
      request.headers["Content-Type"] = "application/json"
      # Umami registers nothing without a user agent, and this one is how the
      # event joins the visitor's own session rather than this container's.
      request.headers["User-Agent"] = user_agent if user_agent.present?
      request.body = JSON.generate(payload_for(feedback, ip: ip, hostname: hostname))
    end

    return if response.success?

    raise ServiceError, "Umami answered #{response.status}"
  rescue Faraday::Error => error
    raise ServiceError, error.message
  end

  private

  def payload_for(feedback, ip:, hostname:)
    {
      type: "event",
      payload: {
        website: @website_id,
        hostname: hostname.presence,
        url: SURFACE_PATHS.fetch(feedback.surface, "/feedback"),
        name: EVENT_NAME,
        data: data_for(feedback),
        # Umami falls back to the request's own address, which is this
        # container's, so the visitor's is named rather than left out.
        ip: ip.presence
      }.compact
    }
  end

  # The visitor's own words, which is the whole point of recording them: the
  # song they wanted, the note they wrote about what got in the way, and the one
  # answer this application offers as a select. Blank halves are left out rather
  # than recorded as empty properties.
  def data_for(feedback)
    {
      feedback_surface: feedback.surface,
      song_query: feedback.query.presence,
      feedback_note: feedback.message.presence,
      feedback_reason: feedback.reason.presence
    }.compact
  end
end
