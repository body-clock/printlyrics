class SongbookEntry < ApplicationRecord
  belongs_to :songbook
  belongs_to :lyric
end
