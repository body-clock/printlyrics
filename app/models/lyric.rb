class Lyric < ApplicationRecord
  belongs_to :song, optional: true

  RETENTION_PERIOD = 180.days

  before_validation :generate_token, :set_expiration, on: :create

  validates :lyrics, presence: true
  validates :token, presence: true, uniqueness: true, length: { is: 16 }
  validates :source_url, length: { maximum: 2_048 }, allow_blank: true

  scope :active, -> { where("expires_at > ?", Time.current) }

  def self.purge_expired!
    where(expires_at: ..Time.current).delete_all
  end

  def to_param
    token
  end

  def renew_retention!
    update_column(:expires_at, RETENTION_PERIOD.from_now)
  end

  STANZA_SEPARATOR = /\r?\n(?:[ \t]*\r?\n)+/

  def stanzas
    lyrics.to_s.strip.split(STANZA_SEPARATOR).map(&:strip)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(12)
  end

  def set_expiration
    self.expires_at ||= RETENTION_PERIOD.from_now
  end
end
