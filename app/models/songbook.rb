class Songbook < ApplicationRecord
  include Retained

  # A songbook only becomes a set once it holds more than one song. The row is
  # created by a click, so a one-song songbook is a draft rather than a set, and
  # this is the threshold the creation event reports.
  SET_SIZE = 2

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
    Lyric.where(id: songbook.entries.select(:lyric_id))
      .update_all(expires_at: RETENTION_PERIOD.from_now)
    songbook
  end

  def append!(lyric)
    # Two tabs adding a song at the same time would otherwise choose the same
    # next position.
    with_lock do
      entries.create!(lyric: lyric, position: (entries.maximum(:position) || 0) + 1)
    end
  end

  def remove!(lyric)
    entries.find_by(lyric_id: lyric.id)&.destroy!
  end

  def a_set?
    entries.count >= SET_SIZE
  end
end
