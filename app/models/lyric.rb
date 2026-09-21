class Lyric < ApplicationRecord
  include Retained

  belongs_to :song, optional: true

  validates :lyrics, presence: true
  validates :title, :artist, length: { maximum: 200 }, allow_blank: true
  validates :source_url, length: { maximum: 2_048 }, allow_blank: true

  STANZA_SEPARATOR = /\r?\n(?:[ \t]*\r?\n)+/

  def stanzas
    lyrics.to_s.strip.split(STANZA_SEPARATOR).map(&:strip)
  end
end
