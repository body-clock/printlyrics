require "test_helper"

class PremiumGrantTest < ActiveSupport::TestCase
  test "recording a payment grants what it bought and keeps the row" do
    user = user_named("granted")
    ends_at = 24.hours.from_now

    grant = record(user, provider_ref: "cs_probe_day_pass", kind: "day_pass", ends_at: ends_at)

    assert grant.persisted?
    assert_equal "stripe", grant.provider
    assert_equal "day_pass", grant.kind
    assert_equal 100, grant.amount_cents
    assert_equal "usd", grant.currency
    assert_in_delta ends_at, user.reload.premium_until, 0.001
    assert user.premium?
  end

  test "a replayed payment records nothing and extends nothing" do
    user = user_named("replayed")

    first = record(user, provider_ref: "cs_probe_replay", kind: "day_pass", ends_at: 24.hours.from_now)
    replayed_ends_at = 48.hours.from_now
    replayed = record(user, provider_ref: "cs_probe_replay", kind: "day_pass", ends_at: replayed_ends_at)

    assert first.previously_new_record?
    assert_not replayed.previously_new_record?
    assert_equal first, replayed
    assert_equal 1, PremiumGrant.count
    assert_in_delta 24.hours.from_now, user.reload.premium_until, 2.seconds
  end

  test "a day pass bought during an active month cannot shorten the access it was bought in" do
    month_ends_at = 30.days.from_now
    user = user_named("premium", premium_until: month_ends_at)

    record(user, provider_ref: "cs_probe_in_month", kind: "day_pass", ends_at: 24.hours.from_now)

    assert_in_delta month_ends_at, user.reload.premium_until, 0.001
  end

  test "a monthly grant moves the entitlement to the later period it names" do
    user = user_named("renewed", premium_until: 10.days.from_now)
    renewed_until = 40.days.from_now

    record(user, provider_ref: "in_probe_1", kind: "monthly", ends_at: renewed_until)

    assert_in_delta renewed_until, user.reload.premium_until, 0.001
  end

  test "recording a grant preserves the songbooks the account already has" do
    user = user_named("keeper")
    lyric = Lyric.create!(lyrics: "Existing words")
    songbook = Songbook.start_with(lyric, user: user)
    assert songbook.expires_at.present?

    record(user, provider_ref: "cs_probe_preserve", kind: "monthly", ends_at: 1.month.from_now)

    assert_nil songbook.reload.expires_at
    assert_nil lyric.reload.expires_at
  end

  test "refuses a provider and a kind this application does not sell" do
    grant = PremiumGrant.new(
      user: user_named("unsold"),
      provider: "paypal",
      provider_ref: "ref",
      kind: "lifetime",
      starts_at: Time.current,
      ends_at: 1.day.from_now
    )

    assert_not grant.valid?
    assert_includes grant.errors[:provider], "is not included in the list"
    assert_includes grant.errors[:kind], "is not included in the list"
  end

  test "refuses a grant with no payment behind it" do
    grant = PremiumGrant.new(user: user_named("empty"), provider_ref: "", kind: "day_pass")

    assert_not grant.valid?
    assert_includes grant.errors[:provider_ref], "can't be blank"
    assert_includes grant.errors[:starts_at], "can't be blank"
    assert_includes grant.errors[:ends_at], "can't be blank"
  end

  private

  def record(user, provider_ref:, kind:, ends_at:)
    PremiumGrant.record!(
      user: user,
      provider_ref: provider_ref,
      kind: kind,
      starts_at: Time.current,
      ends_at: ends_at,
      amount_cents: 100,
      currency: "usd"
    )
  end

  def user_named(name, **attributes)
    User.create!(
      email_address: "#{name}@example.test",
      password: "long-password",
      password_confirmation: "long-password",
      **attributes
    )
  end
end
