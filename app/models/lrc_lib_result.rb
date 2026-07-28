class LrcLibResult
  TIMESTAMP_PREFIX = /\A(?:\[[^\]]+\])+\s*/

  attr_reader :id, :title, :artist, :album, :duration,
              :plain_lyrics, :synced_lyrics, :instrumental

  def initialize(id:, title:, artist:, album:, duration:,
                 plain_lyrics:, synced_lyrics:, instrumental:)
    @id = id
    @title = title
    @artist = artist
    @album = album
    @duration = duration
    @plain_lyrics = plain_lyrics
    @synced_lyrics = synced_lyrics
    @instrumental = instrumental
  end

  def lyrics
    return plain_lyrics.strip if plain_lyrics.present?

    parse_synced_lyrics
  end

  def source_url
    "https://lrclib.net/api/get/#{id}"
  end

  def printable?
    !instrumental && (plain_lyrics.present? || synced_lyrics.present?)
  end

  def deduplication_key
    [ artist, title, album ].map { |value| value.to_s.downcase.squish }
  end

  private

  def parse_synced_lyrics
    synced_lyrics.to_s.lines.filter_map do |line|
      text = line.sub(TIMESTAMP_PREFIX, "").strip
      text if text.present?
    end.join("\n")
  end
end
