# One payment this application has granted premium access for.
#
# The row is the audit trail and the idempotency key at once: Stripe retries a
# delivery it did not get a 2xx for, and the unique index on the provider's own
# reference is what stops a retry from extending the same payment twice. Nothing
# writes here except a verified webhook, and nothing ever updates a row.
#
# The entitlement itself stays on the account (`users.premium_until`, read by
# `User#premium?`); a grant is the record of what bought it.
class PremiumGrant < ApplicationRecord
  PROVIDERS = %w[stripe].freeze
  KINDS = %w[day_pass monthly annual].freeze

  # A day pass is 24 hours from the moment it is granted; a subscription's grant
  # runs to the billing period Stripe reports for it, monthly or yearly.
  DAY_PASS_DURATION = 24.hours

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :provider_ref, presence: true
  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :starts_at, presence: true
  validates :ends_at, presence: true

  # Records one payment and moves the account's entitlement to what it bought.
  #
  # The provider's reference is the idempotency key, so a replayed webhook finds
  # the row instead of writing a second one, and the account is only moved when
  # this call is what created it: `previously_new_record?` on the returned grant
  # is how a caller tells the two apart, and a caller that reports the grant
  # reports only the one it created.
  def self.record!(user:, provider_ref:, kind:, starts_at:, ends_at:, provider: "stripe", amount_cents: nil, currency: nil)
    transaction do
      grant = create_or_find_by!(provider: provider, provider_ref: provider_ref) do |new_grant|
        new_grant.user = user
        new_grant.kind = kind
        new_grant.starts_at = starts_at
        new_grant.ends_at = ends_at
        new_grant.amount_cents = amount_cents
        new_grant.currency = currency
      end

      # The entitlement only ever moves forward, so a day pass bought during an
      # active month cannot shorten it, and a renewal that arrives before the
      # period it replaces has ended cannot either.
      grant.user.activate_premium_until!(grant.ends_at) if grant.previously_new_record?

      grant
    end
  end
end
