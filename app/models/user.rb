class User < ApplicationRecord
  # has_secure_password enforces bcrypt's 72-byte ceiling and no floor, so an
  # account that guards a saved library and a paid entitlement would accept a
  # five-character password. The floor is named here because the register and
  # reset forms state it as well.
  PASSWORD_MINIMUM_LENGTH = 8

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :songbooks, dependent: :destroy
  has_many :identities, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, length: { maximum: 255 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: PASSWORD_MINIMUM_LENGTH }, allow_nil: true

  # What a free account keeps for reprinting, and what premium access removes the
  # ceiling from. An account already holding this many cannot add another until one
  # lapses: an expired book is no longer active, so its place comes free.
  FREE_SONGBOOK_LIMIT = 5

  def premium?
    premium_until&.future? || false
  end

  # Premium access only ever moves forward. A day pass bought during an active
  # month, a renewal delivered before the period it replaces has ended, and a
  # replayed grant all leave the later expiry in place rather than the one they
  # name; a manual grant through the console is the documented experiment path and
  # takes the same route as every purchase.
  def activate_premium_until!(time)
    transaction do
      update!(premium_until: [ premium_until, time ].compact.max)
      songbooks.active.where.not(expires_at: nil).find_each(&:preserve_forever!)
    end
  end

  def can_create_songbook?
    premium? || songbooks.active.count < FREE_SONGBOOK_LIMIT
  end
end
