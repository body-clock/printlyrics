class SongbookEntry < ApplicationRecord
  # A song keeps its own print layout inside a set. These are the same four
  # sizes and two column counts the preview already offers, so a songbook never
  # imposes one format on every song.
  SIZES = %w[s m l xl].freeze
  COLUMNS = [ 1, 2 ].freeze
  COLUMN_STRINGS = COLUMNS.map(&:to_s).freeze
  DEFAULT_SIZE = "m"
  DEFAULT_COLUMNS = 1

  belongs_to :songbook
  belongs_to :lyric

  validates :size, inclusion: { in: SIZES }
  validates :columns, inclusion: { in: COLUMNS }
end
