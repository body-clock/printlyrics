# Server-side validation for the Turnstile widget that gates the feedback form.
# The widget on its own is not a gate: anyone can post any string to the
# endpoint, so the token it produces is worth only what this call confirms.
#
# A token opens this form only when Cloudflare confirms it for the action this
# application renders and a frontend hostname this deployment claims, which is
# what the canonical integration requires: a token minted for another surface,
# or for another host on the same widget, must not pass here.
# See https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
class TurnstileClient
  class Error < StandardError; end

  # Raised when the challenge cannot be judged: the keys or hostnames are not
  # configured, Cloudflare is unreachable, or the reply is unreadable. The
  # caller refuses the submission, because an unjudged challenge is not a pass.
  class ServiceError < Error; end

  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  # The action both feedback forms render; validated against the response.
  ACTION = "feedback"
  # Cloudflare's documented maximum. Anything longer is not a token we issued.
  TOKEN_MAX_LENGTH = 2048

  def initialize(connection: nil, site_key: nil, secret_key: nil, hostnames: nil)
    @site_key = site_key || Rails.configuration.x.turnstile_site_key
    @secret_key = secret_key || Rails.configuration.x.turnstile_secret_key
    @hostnames = hostnames || Rails.configuration.x.turnstile_hostnames
    @connection = connection || Faraday.new do |faraday|
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
      faraday.adapter Faraday.default_adapter
    end
  end

  # True only when Cloudflare confirms the token, for this action, on a hostname
  # this deployment claims. False covers every refusal, including a token minted
  # elsewhere; it is not the same as "could not tell", which raises.
  def verify(token, remote_ip: nil)
    raise ServiceError, "Turnstile keys are not configured" if unconfigured?
    raise ServiceError, "Turnstile hostnames are not configured" if allowed_hostnames.empty?

    token = token.to_s
    return false if token.empty? || token.length > TOKEN_MAX_LENGTH

    response = request(token, remote_ip)
    return false unless response["success"] == true
    return false unless response["action"] == ACTION

    allowed_hostnames.include?(response["hostname"])
  end

  private

  # A gate is armed only when both keys are present: a site key without its
  # secret is a half-configured host, and rejecting every visitor there would
  # break the form rather than protect it.
  def unconfigured?
    @site_key.blank? || @secret_key.blank?
  end

  # Comma-separated, because the deployment supplies it as one environment
  # variable. A production value never includes localhost.
  def allowed_hostnames
    @allowed_hostnames ||= @hostnames.to_s.split(",").map(&:strip).reject(&:empty?)
  end

  # `remoteip` is sent as the canonical integration does, so Cloudflare can weigh
  # the challenge against the visitor it saw. The body is encoded here rather
  # than by a middleware, so the request is identical with any connection,
  # including the test adapter.
  def request(token, remote_ip)
    body = URI.encode_www_form({ secret: @secret_key, response: token, remoteip: remote_ip }.compact)
    response = @connection.post(VERIFY_URL, body,
      "Content-Type" => "application/x-www-form-urlencoded")
    raise ServiceError, "Siteverify returned #{response.status}" unless response.success?

    parsed = JSON.parse(response.body)
    raise ServiceError, "Siteverify returned #{parsed.class}" unless parsed.is_a?(Hash)

    parsed
  rescue JSON::ParserError, Faraday::Error, SocketError, SystemCallError => error
    raise ServiceError, error.message
  end
end
