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

  def self.from_api(row)
    return unless row.is_a?(Hash)

    id = Integer(row["id"], exception: false)
    title = row["trackName"].to_s.strip
    artist = row["artistName"].to_s.strip
    return unless id&.positive? && title.present? && artist.present?

    new(
      id: id,
      title: title,
      artist: artist,
      album: row["albumName"].to_s.strip,
      duration: row["duration"].to_f,
      plain_lyrics: row["plainLyrics"].is_a?(String) ? row["plainLyrics"] : nil,
      synced_lyrics: row["syncedLyrics"].is_a?(String) ? row["syncedLyrics"] : nil,
      instrumental: row["instrumental"] == true
    )
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
