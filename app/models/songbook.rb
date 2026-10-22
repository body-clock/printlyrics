class Songbook < ApplicationRecord
  include Retained

  # A songbook only becomes a set once it holds more than one song. The row is
  # created by a click, so a one-song songbook is a draft rather than a set, and
  # this is the threshold the creation event reports.
  SET_SIZE = 2

  # A set holds a few songs, not a catalog. The offer gathers the sheets a visit
  # already made, so the visit's own list is bounded by the same number, and a
  # set built by hand in one request cannot exceed it either.
  MAX_SONGS = 25

  class LimitReached < StandardError; end

  has_many :entries, -> { order(:position) },
    class_name: "SongbookEntry", dependent: :destroy, inverse_of: :songbook
  has_many :lyrics, through: :entries

  # A set starts from the sheets the visitor already made, in the order they
  # made them, so the first song is the one that carried them here.
  def self.start_with(*lyrics)
    transaction do
      songbook = create!
      lyrics.flatten.each { |lyric| songbook.append!(lyric) }
      songbook
    end
  end

  # A songbook is only as usable as the songs inside it, so a visit renews every
  # member page instead of the set alone.
  def self.renew_retention!(token)
    songbook = super
    return songbook if songbook.expires_at.nil?

    Lyric.where(id: songbook.entries.select(:lyric_id))
      .where.not(expires_at: nil)
      .update_all(expires_at: RETENTION_PERIOD.from_now)
    songbook
  end

  # A kept songbook keeps the songs inside it, including songs added later.
  def preserve!
    transaction do
      update!(expires_at: nil)
      Lyric.where(id: entries.select(:lyric_id)).update_all(expires_at: nil)
    end
  end

  def append!(lyric)
    # Two tabs adding a song at the same time would otherwise choose the same
    # next position.
    with_lock do
      raise LimitReached if entries.count >= MAX_SONGS

      entries.create!(lyric: lyric, position: (entries.maximum(:position) || 0) + 1)
      lyric.update_column(:expires_at, nil) if expires_at.nil?
    end
  end

  def remove!(lyric)
    removed = entries.find_by(lyric_id: lyric.id)&.destroy!
    return unless removed

    # A kept set keeps its songs. Once a song leaves the set, it is kept only if
    # it is on a shelf or inside another kept set. The passed object can predate
    # the set's preservation, so ask the row rather than its cached state.
    lyric.reload
    lyric.release! if lyric.expires_at.nil? && !SavedItem.keeps?(lyric)
    removed
  end

  def a_set?
    entries.count >= SET_SIZE
  end
end
