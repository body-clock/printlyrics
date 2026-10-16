# Receives the events Stripe sends once a payment, a renewal, or a cancellation
# has happened.
#
# This is the only thing that grants premium access: the browser is redirected to
# Stripe and back, and a redirect proves nothing about whether anyone paid, so a
# grant is written here, from a payload whose signature Stripe signed with the
# endpoint's signing secret.
#
# Every verified event is answered 200, including the ones nothing acts on,
# because any other answer is a retry and a retry of an event this application has
# decided not to handle never ends. The refusals are the two cases that mean
# something else: an unverifiable payload (400) and a temporary failure that only
# Stripe can retry (500).
class StripeWebhooksController < ApplicationController
  allow_unauthenticated_access
  # Stripe signs the request instead of carrying a session cookie, and it posts
  # JSON rather than a form: there is no token for CSRF protection to check.
  skip_before_action :verify_authenticity_token

  # Tests replace the Stripe client and the analytics sender through these seams,
  # so no test reaches either service.
  class_attribute :stripe_gateway_factory, default: -> { StripeGateway.new }
  class_attribute :umami_client_factory, default: -> { UmamiClient.new }

  def create
    event = stripe_gateway.parse_webhook(
      payload: request.raw_post,
      signature: request.env["HTTP_STRIPE_SIGNATURE"]
    )
    handle(event)
    head :ok
  rescue StripeGateway::SignatureError
    # Nothing is written for a payload this host cannot verify, so a forged
    # delivery buys no access.
    Rails.logger.warn("Stripe webhook refused: the payload did not verify.")
    head :bad_request
  rescue StripeGateway::ServiceError => error
    # Stripe is the only party that can fix a call that failed while the event
    # was being handled, so the delivery is refused and Stripe retries it. The
    # message names the call, never the payload.
    Rails.logger.warn("Stripe webhook could not be handled (#{error.message}); asking for a retry.")
    head :internal_server_error
  end

  private

  # The parsed event is read with `[]` rather than through generated readers:
  # Stripe renders a webhook payload in the account's own API version, which is
  # not the one the gem pins, and a reference that moved between versions reads
  # as nil here instead of raising.
  def handle(event)
    case event[:type].to_s
    when "checkout.session.completed"
      record_checkout(event[:data][:object])
    when "invoice.paid"
      record_renewal(event[:data][:object])
    when "customer.subscription.deleted"
      forget_subscription(event[:data][:object])
    else
      Rails.logger.info("Stripe webhook #{event[:type]} needs no grant.")
    end
  end

  # The purchase itself. A day pass grants its 24 hours from now; a subscription
  # grants the period it is paid through, which is what a renewal then moves
  # forward.
  def record_checkout(session)
    user = user_for_checkout(session)
    plan = plan_for_checkout(session)

    if user.nil? || plan.nil?
      report_unattributed("checkout session", session[:id])
      return
    end

    billing = subscription_billing(session[:subscription])

    # A subscription plan is granted the period Stripe reports for the
    # subscription it bought, so a session naming none is a payload this
    # application cannot act on rather than one it can guess about.
    if StripeGateway.subscription?(plan) && billing.nil?
      report_unattributed("checkout session", session[:id])
      return
    end

    grant = grant_access(
      user: user,
      provider_ref: session[:id],
      kind: plan,
      ends_at: ends_at_for(billing),
      amount_cents: session[:amount_total],
      currency: session[:currency]
    )

    # The subscription a subscription plan bought is the reference the account
    # keeps while it runs; `customer.subscription.deleted` is what clears it.
    user.update!(stripe_subscription_id: session[:subscription]) if billing

    report_activation(grant)
  end

  # A paid invoice is a renewal: the subscription has advanced into a new period,
  # and the entitlement follows it. The invoice is the idempotency key, so a
  # retried delivery extends nothing a second time; the first invoice of a new
  # subscription arrives here too, and since access only ever moves forward it
  # adds a row without moving the entitlement twice. The plan comes from the
  # subscription's own price, which is what reports a plan the visitor changed in
  # the billing portal.
  def record_renewal(invoice)
    user = User.find_by(stripe_customer_id: invoice[:customer])
    subscription_id = subscription_id_for(invoice)

    if user.nil? || subscription_id.blank?
      report_unattributed("invoice", invoice[:id])
      return
    end

    # Read before the row is written: the call can fail, and a grant naming a
    # period this application never read is one it cannot justify.
    billing = stripe_gateway.subscription_billing(subscription_id)

    grant_access(
      user: user,
      provider_ref: invoice[:id],
      kind: billing.plan,
      ends_at: billing.period_end,
      amount_cents: invoice[:amount_paid],
      currency: invoice[:currency]
    )
  end

  # The end of the recurring plan. Access already granted runs to the expiry it
  # was granted with — nothing here moves it earlier — and the account stops
  # naming a subscription that no longer exists.
  def forget_subscription(subscription)
    user = User.find_by(stripe_subscription_id: subscription[:id]) ||
      User.find_by(stripe_customer_id: subscription[:customer])

    if user.nil?
      report_unattributed("subscription", subscription[:id])
      return
    end

    user.update!(stripe_subscription_id: nil)
  end

  def grant_access(user:, provider_ref:, kind:, ends_at:, amount_cents:, currency:)
    PremiumGrant.record!(
      user: user,
      provider_ref: provider_ref,
      kind: kind,
      starts_at: Time.current,
      ends_at: ends_at,
      amount_cents: amount_cents,
      currency: currency
    )
  end

  # How long the purchase runs: a subscription plan runs to the period Stripe
  # reports for it, and the one-time plan names its own 24 hours from the moment
  # it is granted.
  def ends_at_for(billing)
    billing&.period_end || Time.current + PremiumGrant::DAY_PASS_DURATION
  end

  # What a subscription is billed as, or nil for a session that bought no
  # subscription — which is the shape the one-time plan arrives in.
  def subscription_billing(subscription_id)
    return nil if subscription_id.blank?

    stripe_gateway.subscription_billing(subscription_id)
  end

  # The plan the session was opened for. Two of the three plans are billed as
  # subscriptions, so the session's mode no longer names one; the plan rides the
  # metadata this application set when it opened the session, on a payload whose
  # signature Stripe signed. A value this application does not sell names no
  # plan, and the caller treats that as unattributable.
  def plan_for_checkout(session)
    plan = session[:metadata]&.[](:plan).to_s

    plan if StripeGateway::PLANS.key?(plan)
  end

  # The account the session belongs to: the metadata this application set when it
  # opened the session is the direct answer, and `client_reference_id` carries the
  # same value for a session opened without metadata.
  def user_for_checkout(session)
    user_id = session[:metadata]&.[](:user_id)
    user_id = session[:client_reference_id] if user_id.blank?

    User.find_by(id: user_id) if user_id.present?
  end

  # The subscription an invoice was billed for. Stripe moved this reference under
  # the invoice's parent, and an account on either version is understood here.
  def subscription_id_for(invoice)
    parent = invoice[:parent]

    invoice[:subscription] || parent&.[](:subscription_details)&.[](:subscription)
  end

  # The ledger row is written by the time this runs, so the report is about a
  # grant that exists rather than part of granting it. A replay of the same event
  # finds the row instead and reports nothing, so a Stripe retry is not a second
  # activation.
  def report_activation(grant)
    return unless grant.previously_new_record?

    client = umami_client
    return unless client.configured?

    client.record_premium_activation(hostname: request.host)
  rescue UmamiClient::ServiceError => error
    Rails.logger.warn("Premium grant #{grant.id} was not recorded in analytics (#{error.message}).")
  end

  # A verified event naming an account this application cannot match is a bug
  # rather than traffic. It would otherwise disappear, because the answer has to
  # be 200 or Stripe retries a payload nothing will ever handle — so it is
  # reported the way this application reports any unexpected server error, with
  # the reference and no payload.
  def report_unattributed(reference, id)
    description = [ "Stripe webhook named no account for", reference, id ].compact.join(" ")
    Rails.logger.error(description)
    Honeybadger.notify(description, context: { stripe_reference: reference })
  end

  def stripe_gateway
    @stripe_gateway ||= self.class.stripe_gateway_factory.call
  end

  def umami_client
    @umami_client ||= self.class.umami_client_factory.call
  end
end
