class Songbook < ApplicationRecord
  include Retained

  SET_SIZE = 2
  MAX_SONGS = 25

  belongs_to :user, optional: true
  validates :share_token, uniqueness: true, allow_nil: true
  has_many :entries, -> { order(:position) },
    class_name: "SongbookEntry", dependent: :destroy, inverse_of: :songbook
  has_many :lyrics, through: :entries

  class DailyLimitReached < StandardError; end

  def self.start_with(*lyrics, user: nil, visitor_key: nil)
    lyrics = lyrics.flatten

    transaction do
      if user
        user.with_lock do
          raise DailyLimitReached unless user.can_create_songbook?

          create_with_lyrics(lyrics, user, visitor_key)
        end
      else
        create_with_lyrics(lyrics, nil, visitor_key)
      end
    end
  end

  def self.create_with_lyrics(lyrics, user, visitor_key)
    songbook = create!(user: user, visitor_key: visitor_key)
    songbook.preserve_forever! if user&.premium?
    lyrics.each { |lyric| songbook.append!(lyric) }
    songbook
  end
  private_class_method :create_with_lyrics

  def self.renew_retention!(token)
    songbook = active.find_by!(token: token)
    return songbook if songbook.expires_at.nil?

    songbook.touch_retention!
    Lyric.where(id: songbook.entries.select(:lyric_id))
      .where.not(expires_at: nil)
      .update_all(expires_at: RETENTION_PERIOD.from_now)
    songbook
  end

  def append!(lyric)
    with_lock do
      entries.create!(lyric: lyric, position: (entries.maximum(:position) || 0) + 1)
      lyric.update_column(:expires_at, nil) if expires_at.nil?
    end
  end

  def preserve_forever!
    update!(expires_at: nil)
    Lyric.where(id: entries.select(:lyric_id)).update_all(expires_at: nil)
  end

  def enable_sharing!
    raise ArgumentError, "active premium access is required" unless user&.premium?
    return false if share_token.present?

    update!(share_token: SecureRandom.urlsafe_base64(24))
  end

  def revoke_sharing!
    return false if share_token.nil?

    update!(share_token: nil)
  end

  def sharing_active?
    share_token.present? && user&.premium?
  end

  def remove!(lyric)
    entries.find_by(lyric_id: lyric.id)&.destroy!
  end

  def a_set?
    entries.count >= SET_SIZE
  end
end
