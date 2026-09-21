# Token-addressed records stay reachable at an unlisted URL for a fixed window
# and extend that window on every visit. Lyric pages and songbooks share the
# contract so token format, retention, and lookup failure behave identically on
# both surfaces.
module Retained
  extend ActiveSupport::Concern

  RETENTION_PERIOD = 180.days

  included do
    before_validation :generate_token, :set_expiration, on: :create

    validates :token, presence: true, uniqueness: true, length: { is: 16 }

    scope :active, -> { where("expires_at > ?", Time.current) }
  end

  class_methods do
    def purge_expired!
      where(expires_at: ..Time.current).delete_all
    end

    # Look up an active record and extend its retention in one step, so callers
    # never hold an expired record. Raises RecordNotFound for expired or unknown
    # tokens, which callers present as "expired or wasn't found".
    def renew_retention!(token)
      record = active.find_by!(token: token)
      record.touch_retention!
      record
    end
  end

  def to_param
    token
  end

  def touch_retention!
    update_column(:expires_at, RETENTION_PERIOD.from_now)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(12)
  end

  def set_expiration
    self.expires_at ||= RETENTION_PERIOD.from_now
  end
end
