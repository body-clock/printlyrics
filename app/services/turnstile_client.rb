# Server-side validation for the Turnstile widget that gates the feedback form.
# The widget on its own is not a gate: anyone can post any string to the
# endpoint, so the token it produces is worth only what this call confirms.
# See https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
class TurnstileClient
  class Error < StandardError; end

  # Raised when the challenge cannot be judged at all: no keys are configured,
  # Cloudflare is unreachable, or the reply is unreadable. Callers decide what
  # that means; the feedback form stores the submission unverified rather than
  # discarding a real reply.
  class ServiceError < Error; end

  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"
  # Cloudflare's documented maximum. Anything longer is not a token we issued.
  TOKEN_MAX_LENGTH = 2048

  def initialize(connection: nil, site_key: nil, secret_key: nil)
    @site_key = site_key || Rails.configuration.x.turnstile_site_key
    @secret_key = secret_key || Rails.configuration.x.turnstile_secret_key
    @connection = connection || Faraday.new do |faraday|
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
      faraday.adapter Faraday.default_adapter
    end
  end

  # True when Cloudflare confirms the token, false when it rejects it or when no
  # token was submitted at all.
  def verify(token)
    raise ServiceError, "Turnstile keys are not configured" if unconfigured?

    token = token.to_s
    return false if token.empty? || token.length > TOKEN_MAX_LENGTH

    case request(token)["success"]
    when true then true
    when false then false
    else raise ServiceError, "Unexpected siteverify response"
    end
  end

  private

  # A gate is armed only when both keys are present. A site key without its
  # secret is a half-configured host, and rejecting every submission there would
  # break the form rather than protect it.
  def unconfigured?
    @site_key.blank? || @secret_key.blank?
  end

  # `remoteip` is deliberately not sent: Cloudflare already sees the visitor's
  # address when the widget runs, and the parameter is optional. The body is
  # encoded here rather than by a middleware, so the request is identical with
  # any connection, including the test adapter.
  def request(token)
    body = URI.encode_www_form(secret: @secret_key, response: token)
    response = @connection.post(VERIFY_URL, body,
      "Content-Type" => "application/x-www-form-urlencoded")
    raise ServiceError, "Siteverify returned #{response.status}" unless response.success?

    body = JSON.parse(response.body)
    raise ServiceError, "Siteverify returned #{body.class}" unless body.is_a?(Hash)

    body
  rescue JSON::ParserError, Faraday::Error, SocketError, SystemCallError => error
    raise ServiceError, error.message
  end
end
