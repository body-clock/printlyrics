# One place on an account's shelf.
#
# A lyric sheet and a songbook are different records but the same product idea
# here: something the visitor made and wants to print again. The row is
# polymorphic so the shelf has one count and one cap, and the item keeps a nil
# expiry while it is on the shelf.
class SavedItem < ApplicationRecord
  LIMIT = 10
  ITEM_TYPES = %w[Lyric Songbook].freeze

  belongs_to :user
  belongs_to :item, polymorphic: true

  validates :item_type, inclusion: { in: ITEM_TYPES }
  validates :item_id, uniqueness: { scope: %i[user_id item_type] }

  class LimitReached < StandardError; end

  # The types come from a fixed map rather than `constantize`, so a request can
  # only ever reach the two records the shelf is for.
  def self.item_class(type)
    { "Lyric" => Lyric, "Songbook" => Songbook }[type]
  end

  def self.add(user:, item:)
    unless ITEM_TYPES.include?(item.class.name)
      raise ArgumentError, "#{item.class.name} cannot be saved to a library"
    end

    transaction do
      user.with_lock do
        existing = where(user: user, item: item).first
        next existing if existing

        raise LimitReached if user.saved_items.count >= LIMIT

        create!(user: user, item: item).tap { item.preserve! }
      end
    end
  end

  # Removing an item puts it back on the anonymous 180-day clock, unless it is
  # still reachable through any saved item: token pages can be saved by more
  # than one account, and a song can sit in a kept songbook.
  def release!
    transaction do
      destroy!
      next if item.nil?

      if item.is_a?(Songbook)
        next if SavedItem.exists?(item: item)

        item.release!
        release_songbook_lyrics
      elsif !SavedItem.exists?(item: item) && !saved_songbook_containing(item).exists?
        item.release!
      end
    end
  end

  private

  def release_songbook_lyrics
    item.lyrics.find_each do |lyric|
      next if SavedItem.exists?(item: lyric)
      next if saved_songbook_containing(lyric).exists?

      lyric.release!
    end
  end

  def saved_songbook_containing(lyric)
    SavedItem.where(item_type: "Songbook").where(
      item_id: Songbook.joins(:entries)
        .where(songbook_entries: { lyric_id: lyric.id })
        .select(:id)
    )
  end
end
