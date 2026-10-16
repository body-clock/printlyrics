# A third-party account a print account signs in with.
#
# The row is the mapping and the uid is the key: an address can be changed at
# either end, while the uid Google sends back is the same every time. `provider`
# is part of the key so a second provider costs a row, not a migration, and no
# address is stored here at all — the account's own address is the one place this
# application keeps it.
class Identity < ApplicationRecord
  PROVIDERS = %w[google_oauth2].freeze

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
end
