# A third-party account a PrintLyrics account signs in with.
#
# The provider and uid are the key. An address can change at either end while
# the uid Google sends back stays the same, so the identity row is what a
# returning visitor is found by.
class Identity < ApplicationRecord
  PROVIDERS = %w[google_oauth2].freeze

  belongs_to :user

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :uid, presence: true, uniqueness: { scope: :provider }
end
