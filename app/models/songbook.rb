class Songbook < ApplicationRecord
  include Retained

  SET_SIZE = 2

  # What one book holds. A book owned by an account with active premium access is
  # bounded by nothing here: it grows a song at a time, and the visit that gathers
  # sheets into one is bounded by the session cookie that holds those sheets.
  FREE_SONG_LIMIT = 10

  # The most tokens one request may claim. A guard on the work a single request can
  # ask for rather than a product rule — no flow reaches it, because the visit's own
  # list is shorter — and a book grows past it one song at a time.
  REQUEST_LIMIT = 100

  belongs_to :user, optional: true
  validates :share_token, uniqueness: true, allow_nil: true
  has_many :entries, -> { order(:position) },
    class_name: "SongbookEntry", dependent: :destroy, inverse_of: :songbook
  has_many :lyrics, through: :entries

  class StorageLimitReached < StandardError; end
  class SongLimitReached < StandardError; end

  # The songs one book may hold, or nil when the account that owns it has premium
  # access and there is no product limit to apply. One definition, read by the
  # request that fills a book and by the book itself.
  def self.song_limit_for(user)
    user&.premium? ? nil : FREE_SONG_LIMIT
  end

  def self.start_with(*lyrics, user: nil, visitor_key: nil)
    lyrics = lyrics.flatten

    transaction do
      if user
        user.with_lock do
          raise StorageLimitReached unless user.can_create_songbook?

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

  # The limit on this book, or nil when its account's premium access removes it.
  def song_limit = self.class.song_limit_for(user)

  def full?
    limit = song_limit
    limit.present? && entries.count >= limit
  end

  def append!(lyric)
    with_lock do
      raise SongLimitReached if full?

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
