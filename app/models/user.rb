class User < ApplicationRecord
  # has_secure_password enforces bcrypt's 72-byte ceiling and no floor. The
  # register and reset forms state this value, and the model enforces it.
  PASSWORD_MINIMUM_LENGTH = 8

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :identities, dependent: :destroy
  has_many :saved_items, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    length: { maximum: 255 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: PASSWORD_MINIMUM_LENGTH }, allow_nil: true

  # The library is a fixed shelf, not a subscription. Both kinds of saved page
  # compete for the same ten places.
  def library_full? = saved_items.count >= SavedItem::LIMIT

  def saved?(item) = saved_items.exists?(item: item)
end
