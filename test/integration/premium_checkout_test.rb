require "test_helper"
require "openssl"

# The premium slice end to end: what a page renders, what the checkout action
# starts, and what the webhook grants. The Stripe client is replaced through the
# controllers' factory seam, and the two payloads that need no Stripe call at all
# (the refused signature and the day pass) travel through the real client, so the
# signature path under test is the one that runs in production.
class PremiumCheckoutTest < ActionDispatch::IntegrationTest
  WEBHOOK_SECRET = "whsec_probe_secret".freeze
  SIGNATURE_HEADER = "t=1,v1=probe".freeze

  # A Stand-in for StripeGateway that answers like the real one, records what it
  # was asked, and never leaves this process. A webhook payload is set as a hash
  # and parsed into a real Stripe event, so the controller reads the shapes Stripe
  # itself sends.
  class FakeStripeGateway
    attr_reader :customers, :checkouts, :portals, :period_lookups
    attr_writer :event

    def initialize(period_end: nil, configured: true)
      @configured = configured
      @period_end = period_end
      @event = { type: "unhandled.event", data: { object: {} } }
      @customers = []
      @checkouts = []
      @portals = []
      @period_lookups = []
    end

    def configured?
      @configured
    end

    def create_customer(email:)
      @customers << email
      "cus_probe_#{@customers.size}"
    end

    def create_checkout(plan:, customer_id:, success_url:, cancel_url:, reference:)
      @checkouts << {
        plan: plan,
        customer_id: customer_id,
        success_url: success_url,
        cancel_url: cancel_url,
        reference: reference
      }
      "https://checkout.stripe.test/#{plan}"
    end

    def create_billing_portal_session(customer_id:, return_url:)
      @portals << { customer_id: customer_id, return_url: return_url }
      "https://billing.stripe.test/session"
    end

    def subscription_period_end(subscription_id)
      @period_lookups << subscription_id
      @period_end
    end

    def parse_webhook(payload:, signature:)
      raise StripeGateway::SignatureError, "unsigned" if signature.blank?

      Stripe::Event.construct_from(@event)
    end
  end

  class FakeAnalyticsClient
    attr_reader :activations

    def initialize(configured: true)
      @configured = configured
      @activations = []
    end

    def configured?
      @configured
    end

    def record_premium_activation(hostname: nil)
      @activations << hostname
    end
  end

  test "an unconfigured host renders the proposal wording and no purchase control" do
    get save_songbooks_path

    assert_response :success
    assert_select "h2", text: I18n.t("songbook_saving.options.heading")
    assert_select "p", text: I18n.t("songbook_saving.payment_status")
    assert_select "p", text: I18n.t("songbook_saving.callout.body")
    assert_select "form[action=?]", premium_checkout_path, count: 0
  end

  test "a configured host renders both plans as controls" do
    with_stripe_configured do
      get save_songbooks_path
    end

    assert_response :success
    assert_select "h2", text: I18n.t("songbook_saving.options.heading_available")
    assert_select "form[action=?]", premium_checkout_path, count: 2
    assert_select "form[data-analytics-submit=?]", "Premium Checkout Started", count: 2
    assert_select "input[name=plan][value=?]", "monthly", count: 1
    assert_select "input[name=plan][value=?]", "day_pass", count: 1
    assert_select "button", text: I18n.t("songbook_saving.checkout.monthly")
    assert_select "button", text: I18n.t("songbook_saving.checkout.day_pass")
    assert_select "p", text: I18n.t("songbook_saving.payment_status"), count: 0
  end

  test "the checkout refuses a plan this application does not sell" do
    gateway = FakeStripeGateway.new
    sign_in(new_user)

    with_stripe_gateway(gateway) do
      post premium_checkout_path, params: { plan: "lifetime" }
    end

    assert_redirected_to save_songbooks_path
    assert_equal I18n.t("premium.checkout.unknown_plan"), flash[:alert]
    assert_empty gateway.checkouts
  end

  test "the checkout refuses when this host cannot sell and stores no customer" do
    user = new_user
    sign_in(user)

    post premium_checkout_path, params: { plan: "monthly" }

    assert_redirected_to save_songbooks_path
    assert_equal I18n.t("premium.checkout.unavailable"), flash[:alert]
    assert_nil user.reload.stripe_customer_id
    assert_equal 0, PremiumGrant.count
  end

  test "a plan clicked while signed out returns to the plans after signing in" do
    user = new_user

    post premium_checkout_path, params: { plan: "monthly" }

    assert_redirected_to new_session_path

    # This action answers to POST alone, so the sign-in it required must come
    # back to the page the plan was chosen on: returning to the action's own URL
    # would be a GET at a route that has none.
    post session_path, params: { email_address: user.email_address, password: "long-password" }

    assert_redirected_to save_songbooks_url
  end

  test "a checkout creates the customer once, reuses it, and grants nothing by returning" do
    gateway = FakeStripeGateway.new
    user = new_user
    sign_in(user)

    with_stripe_gateway(gateway) do
      post premium_checkout_path, params: { plan: "monthly" }
      assert_redirected_to "https://checkout.stripe.test/monthly"

      post premium_checkout_path, params: { plan: "day_pass" }
      assert_redirected_to "https://checkout.stripe.test/day_pass"
    end

    assert_equal [ user.email_address ], gateway.customers
    assert_equal %w[monthly day_pass], gateway.checkouts.map { |checkout| checkout[:plan] }
    assert_equal [ "cus_probe_1", "cus_probe_1" ], gateway.checkouts.map { |checkout| checkout[:customer_id] }
    assert_equal "cus_probe_1", user.reload.stripe_customer_id

    checkout = gateway.checkouts.first
    assert_equal account_songbooks_url(checkout: "return"), checkout[:success_url]
    assert_equal save_songbooks_url, checkout[:cancel_url]
    assert_equal user.id.to_s, checkout[:reference]

    # The return URL is a page anyone can open, so starting a checkout grants
    # nothing: the webhook is what does.
    assert_nil user.reload.premium_until
    assert_equal 0, PremiumGrant.count
  end

  test "the library says the payment is confirming rather than that access is granted" do
    user = new_user
    sign_in(user)

    get account_songbooks_path(checkout: "return")
    assert_response :success
    assert_select "p[role=status]", text: I18n.t("accounts.library.checkout_returned")

    get account_songbooks_path
    assert_response :success
    assert_select "p[role=status]", count: 0
    assert_nil user.reload.premium_until
  end

  test "the billing portal needs a stored customer" do
    gateway = FakeStripeGateway.new
    sign_in(new_user)

    with_stripe_gateway(gateway) do
      post billing_portal_path
    end

    assert_redirected_to account_songbooks_path
    assert_equal I18n.t("premium.billing_portal.unavailable"), flash[:alert]
    assert_empty gateway.portals
  end

  test "an account that has paid is sent to Stripe to manage or cancel" do
    gateway = FakeStripeGateway.new
    user = new_user(stripe_customer_id: "cus_probe_existing")
    sign_in(user)

    with_stripe_gateway(gateway) do
      post billing_portal_path
    end

    assert_redirected_to "https://billing.stripe.test/session"
    assert_equal [ { customer_id: "cus_probe_existing", return_url: account_songbooks_url } ], gateway.portals
  end

  test "the library offers the billing control only to a paid account on a host that can sell" do
    user = new_user(stripe_customer_id: "cus_probe_existing")
    sign_in(user)

    get account_songbooks_path
    assert_select "form[action=?]", billing_portal_path, count: 0

    with_stripe_configured do
      get account_songbooks_path
    end
    assert_select "form[action=?]", billing_portal_path, count: 1
  end

  test "a payload that does not verify is refused and grants nothing" do
    user = new_user
    payload, signature = signed_payload(checkout_completed(day_pass_session(user)))

    with_stripe_configured(webhook_secret: WEBHOOK_SECRET) do
      post stripe_webhook_path, params: payload, headers: webhook_headers("#{signature}00")
    end

    assert_response :bad_request
    assert_equal 0, PremiumGrant.count
    assert_nil user.reload.premium_until
  end

  test "a day pass checkout grants its 24 hours" do
    user = new_user
    payload, signature = signed_payload(checkout_completed(day_pass_session(user)))

    with_stripe_configured(webhook_secret: WEBHOOK_SECRET) do
      post stripe_webhook_path, params: payload, headers: webhook_headers(signature)
    end

    assert_response :success
    grant = PremiumGrant.sole
    assert_equal "day_pass", grant.kind
    assert_equal "stripe", grant.provider
    assert_equal "cs_probe_day_pass", grant.provider_ref
    assert_equal 100, grant.amount_cents
    assert_equal "usd", grant.currency
    assert_in_delta 24.hours.from_now, user.reload.premium_until, 2.seconds
    assert user.premium?
  end

  test "a delivery Stripe retries grants once and reports one activation" do
    user = new_user
    payload, signature = signed_payload(checkout_completed(day_pass_session(user)))
    analytics = FakeAnalyticsClient.new

    with_stripe_configured(webhook_secret: WEBHOOK_SECRET) do
      with_premium_analytics(analytics) do
        2.times { post stripe_webhook_path, params: payload, headers: webhook_headers(signature) }
      end
    end

    assert_response :success
    assert_equal 1, PremiumGrant.count
    assert_in_delta 24.hours.from_now, user.reload.premium_until, 2.seconds
    assert_equal 1, analytics.activations.size
  end

  test "the monthly plan stores the subscription and grants the period it is paid for" do
    user = new_user
    period_end = 1.month.from_now
    gateway = FakeStripeGateway.new(period_end: period_end)
    gateway.event = checkout_completed(subscription_session(user))

    with_stripe_gateway(gateway) { post_webhook }

    assert_response :success
    assert_equal [ "sub_probe_1" ], gateway.period_lookups
    assert_equal "sub_probe_1", user.reload.stripe_subscription_id
    assert_in_delta period_end, user.premium_until, 0.001
    assert_equal "monthly", PremiumGrant.sole.kind
  end

  test "a paid invoice extends access to the new period" do
    user = new_user(stripe_customer_id: "cus_probe_existing", premium_until: 1.day.from_now)
    new_period_end = 2.months.from_now
    gateway = FakeStripeGateway.new(period_end: new_period_end)
    gateway.event = {
      id: "evt_probe",
      object: "event",
      type: "invoice.paid",
      data: { object: {
        id: "in_probe_1",
        object: "invoice",
        customer: "cus_probe_existing",
        subscription: "sub_probe_1",
        amount_paid: 500,
        currency: "usd"
      } }
    }

    with_stripe_gateway(gateway) { post_webhook }

    assert_response :success
    assert_equal "monthly", PremiumGrant.sole.kind
    assert_equal "in_probe_1", PremiumGrant.sole.provider_ref
    assert_in_delta new_period_end, user.reload.premium_until, 0.001
  end

  test "a deleted subscription moves no expiry and clears the stored subscription" do
    expires_at = 10.days.from_now
    user = new_user(
      stripe_customer_id: "cus_probe_existing",
      stripe_subscription_id: "sub_probe_1",
      premium_until: expires_at
    )
    gateway = FakeStripeGateway.new
    gateway.event = {
      id: "evt_probe",
      object: "event",
      type: "customer.subscription.deleted",
      data: { object: {
        id: "sub_probe_1",
        object: "subscription",
        customer: "cus_probe_existing",
        status: "canceled"
      } }
    }

    with_stripe_gateway(gateway) { post_webhook }

    assert_response :success
    user.reload
    assert_nil user.stripe_subscription_id
    assert_equal "cus_probe_existing", user.stripe_customer_id
    assert_in_delta expires_at, user.premium_until, 0.001
    assert_equal 0, PremiumGrant.count
  end

  test "an event this application does not act on is answered so Stripe stops retrying" do
    gateway = FakeStripeGateway.new
    gateway.event = { id: "evt_probe", object: "event", type: "customer.created", data: { object: { id: "cus_probe_9", object: "customer" } } }

    with_stripe_gateway(gateway) { post_webhook }

    assert_response :success
    assert_equal 0, PremiumGrant.count
  end

  test "an event that names no account is reported rather than swallowed" do
    gateway = FakeStripeGateway.new
    gateway.event = checkout_completed(day_pass_session(nil))
    reports = []

    recording_honeybadger_notices(reports) do
      with_stripe_gateway(gateway) { post_webhook }
    end

    assert_response :success
    assert_equal 0, PremiumGrant.count
    assert_equal 1, reports.size
    assert_match(/cs_probe_day_pass/, reports.first.first)
    assert_equal "checkout session", reports.first.last.dig(:context, :stripe_reference)
  end

  private

  def post_webhook
    post stripe_webhook_path, params: "{}", headers: webhook_headers(SIGNATURE_HEADER)
  end

  def webhook_headers(signature)
    { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
  end

  # A payload Stripe could have sent, signed the way the SDK's construct_event
  # verifies, so the real verification path runs without a network.
  def signed_payload(event)
    payload = JSON.generate(event)
    timestamp = Time.current.to_i
    signature = OpenSSL::HMAC.hexdigest("SHA256", WEBHOOK_SECRET, "#{timestamp}.#{payload}")

    [ payload, "t=#{timestamp},v1=#{signature}" ]
  end

  def checkout_completed(session)
    { id: "evt_probe", object: "event", type: "checkout.session.completed", data: { object: session } }
  end

  def day_pass_session(user)
    {
      id: "cs_probe_day_pass",
      object: "checkout.session",
      mode: "payment",
      amount_total: 100,
      currency: "usd",
      client_reference_id: user&.id&.to_s,
      metadata: user ? { user_id: user.id.to_s } : {},
      subscription: nil
    }
  end

  def subscription_session(user)
    {
      id: "cs_probe_monthly",
      object: "checkout.session",
      mode: "subscription",
      amount_total: 500,
      currency: "usd",
      client_reference_id: user.id.to_s,
      metadata: { user_id: user.id.to_s },
      subscription: "sub_probe_1"
    }
  end

  # Minitest 6 ships no stub, so the reporter is swapped by hand for one test and
  # put back afterwards.
  def recording_honeybadger_notices(reports)
    original = Honeybadger.method(:notify)
    Honeybadger.define_singleton_method(:notify) { |*arguments| reports << arguments }
    yield
  ensure
    Honeybadger.define_singleton_method(:notify, original)
  end

  def new_user(**attributes)
    @user_count = (@user_count || 0) + 1
    User.create!(
      email_address: "buyer#{@user_count}@example.test",
      password: "long-password",
      password_confirmation: "long-password",
      **attributes
    )
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "long-password" }
    follow_redirect! if response.redirect?
  end
end
