# The application's one conversation with Stripe.
#
# Checkout is where the money happens and this application never sees a card: it
# opens a session, sends the visitor to Stripe's own page, and learns what
# happened from the webhook. Everything here is transport — a customer, the two
# Checkout Sessions, a billing portal session, a verified webhook payload, a
# subscription's current period — and every response is reduced to a plain value,
# so no Stripe object leaves this file.
#
# Errors follow this project's client convention (TurnstileClient, UmamiClient):
# one `Error` family, a `ServiceError` for "that could not be done", and a
# signature failure in a class of its own because the caller answers it as a
# refusal rather than a failure.
class StripeGateway
  class Error < StandardError; end

  # Raised when Stripe is not configured, refused the call, or could not be
  # reached. No payment state is real until a verified webhook says so, so the
  # caller's job is only to say that the checkout did not start.
  class ServiceError < Error; end

  # Raised for a payload this host cannot verify: a signature that does not match
  # the endpoint's signing secret, a body that is not JSON, or a host with no
  # signing secret to check against. The caller refuses it and writes nothing.
  class SignatureError < Error; end

  # The three plans this application sells, and what each one needs from Stripe:
  # the Checkout mode it is bought in, and the environment variable the
  # initializer reads its price from. The plan names are the ledger's
  # `PremiumGrant::KINDS`, so the visitor's choice, the session Stripe creates,
  # and the grant the webhook records all come from this one table.
  PLANS = {
    "day_pass" => { mode: "payment", price_config: :stripe_price_day_pass },
    "monthly" => { mode: "subscription", price_config: :stripe_price_monthly },
    "annual" => { mode: "subscription", price_config: :stripe_price_annual }
  }.freeze

  # Whether a plan is billed as a subscription, which is what decides whether the
  # purchase grants a billing period or a fixed duration.
  def self.subscription?(plan)
    PLANS.dig(plan.to_s, :mode) == "subscription"
  end

  # What one subscription is currently billed as: the plan its price buys, and the
  # end of the period it is paid through. Two of the three plans are billed as
  # subscriptions, so the price is what tells them apart — the session's mode
  # names no single plan, and a renewal has no session at all.
  Subscription = Data.define(:plan, :period_end)

  # Whether this host can sell anything at all. All five configured values are
  # required together: a host that could take a payment but not verify the
  # webhook that grants access would take money and grant nothing. Nothing raises
  # when they are absent — this is the predicate, and it is false.
  def self.configured?
    new.configured?
  end

  def initialize(secret_key: nil, webhook_secret: nil, monthly_price_id: nil, annual_price_id: nil,
    day_pass_price_id: nil)
    @secret_key = secret_key || Rails.configuration.x.stripe_secret_key
    @webhook_secret = webhook_secret || Rails.configuration.x.stripe_webhook_secret
    overrides = {
      "day_pass" => day_pass_price_id,
      "monthly" => monthly_price_id,
      "annual" => annual_price_id
    }
    @price_ids = PLANS.to_h do |plan, config|
      [ plan, overrides[plan].presence || Rails.configuration.x.public_send(config[:price_config]) ]
    end
  end

  def configured?
    @secret_key.present? && @webhook_secret.present? && @price_ids.values.none?(&:blank?)
  end

  # The customer every later payment, invoice, and billing portal session for an
  # account hangs from. Created once, on the first checkout, and stored on the
  # account.
  def create_customer(email:)
    ensure_configured!
    stripe { Stripe::Customer.create({ email: email }, request_options) }.id
  end

  # The plan-driven entry the checkout action uses: the mode that buys a plan and
  # the price it is configured with both live in PLANS, so the action names a plan
  # and nothing else.
  def create_checkout(plan:, customer_id:, success_url:, cancel_url:, reference:)
    config = PLANS.fetch(plan) { raise ArgumentError, "unknown plan: #{plan.inspect}" }
    arguments = {
      plan: plan,
      customer_id: customer_id,
      price_id: @price_ids.fetch(plan),
      success_url: success_url,
      cancel_url: cancel_url,
      reference: reference
    }

    if config[:mode] == "subscription"
      create_subscription_checkout(**arguments)
    else
      create_payment_checkout(**arguments)
    end
  end

  # A Checkout Session for a recurring plan, answered with the URL Stripe hosts the
  # payment on.
  def create_subscription_checkout(plan:, customer_id:, price_id:, success_url:, cancel_url:, reference:)
    checkout_session("subscription", plan:, customer_id:, price_id:, success_url:, cancel_url:, reference:)
  end

  # A Checkout Session for the one-time plan: one payment, no subscription behind
  # it.
  def create_payment_checkout(plan:, customer_id:, price_id:, success_url:, cancel_url:, reference:)
    checkout_session("payment", plan:, customer_id:, price_id:, success_url:, cancel_url:, reference:)
  end

  # The Stripe-hosted page where an account changes or cancels what it pays for.
  # The return URL is this application's own, so the visitor comes back.
  def create_billing_portal_session(customer_id:, return_url:)
    ensure_configured!
    stripe { Stripe::BillingPortal::Session.create({ customer: customer_id, return_url: return_url }, request_options) }.url
  end

  # Verifies a webhook payload's signature against the endpoint's signing secret
  # and parses it. The parsed event is read with `[]` by the caller rather than
  # through generated readers, because Stripe renders a webhook payload in the
  # account's own API version, which is not the one this gem pins.
  def parse_webhook(payload:, signature:)
    raise SignatureError, "no signing secret is configured" if @webhook_secret.blank?

    Stripe::Webhook.construct_event(payload, signature, @webhook_secret)
  rescue Stripe::SignatureVerificationError, JSON::ParserError => error
    raise SignatureError, error.message
  rescue Stripe::StripeError => error
    raise ServiceError, error.message
  end

  # The plan a price buys, which is how a renewal is named: the invoice it arrives
  # on carries no plan of its own, and a plan changed in the billing portal
  # reports itself by its new price.
  def plan_for_price_id(price_id)
    return nil if price_id.blank?

    @price_ids.find { |_plan, configured_id| configured_id == price_id }&.first
  end

  # What a subscription is currently billed as, and the period it is paid
  # through. Stripe moved the period from the subscription onto its items, and
  # this call pins the gem's API version, so the items are what it reads.
  def subscription_billing(subscription_id)
    ensure_configured!
    item = stripe { Stripe::Subscription.retrieve(subscription_id, request_options) }.items.data.first
    plan = plan_for_price_id(item&.price&.id)

    if plan.nil?
      raise ServiceError, "subscription #{subscription_id} bills a price this application does not sell"
    end
    if item.current_period_end.blank?
      raise ServiceError, "subscription #{subscription_id} reports no billing period"
    end

    Subscription.new(plan: plan, period_end: Time.zone.at(item.current_period_end))
  end

  private

  def checkout_session(mode, plan:, customer_id:, price_id:, success_url:, cancel_url:, reference:)
    ensure_configured!
    session = stripe do
      Stripe::Checkout::Session.create(
        {
          mode: mode,
          customer: customer_id,
          client_reference_id: reference,
          # The webhook grants access from the account this names, so the visitor
          # does not have to be signed in on the device the payment confirms on.
          # The plan travels here as well, because two of the three plans are
          # billed as subscriptions: the session's mode no longer names one plan,
          # and this is the value this application set when it opened the session.
          metadata: { user_id: reference, plan: plan },
          line_items: [ { price: price_id, quantity: 1 } ],
          success_url: success_url,
          cancel_url: cancel_url
        },
        request_options
      )
    end
    session.url
  end

  # Every call into the SDK goes through here, so one place decides what an SDK
  # failure means for this application. Stripe's own message names the problem
  # and masks the key.
  def stripe
    yield
  rescue Stripe::StripeError => error
    raise ServiceError, error.message
  end

  # Per request rather than on the global Stripe.api_key, so what this object
  # calls with cannot be changed by another caller in the same process.
  def request_options
    { api_key: @secret_key }
  end

  def ensure_configured!
    raise ServiceError, "Stripe is not configured" unless configured?
  end
end
