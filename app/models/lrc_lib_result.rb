class LrcLibResult
  TIMESTAMP_PREFIX = /\A(?:\[[^\]]+\])+\s*/

  # Video titles arrive as "Artist - Song (Official Lyric Video)"; the sheet
  # should carry the song, not the upload title. Only a leading repeat of the
  # artist field and bracketed format noise are removed, so a title that keeps
  # the artist's name in its own words ("Queen of the Night") is untouched.
  TITLE_NOISE = /[\[(][^\])]*(?:official|lyric|lyrics|audio|video|hd|hq|remaster|remastered)[^\])]*[\])]/i

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
    artist = row["artistName"].to_s.strip
    title = normalize_title(row["trackName"].to_s.strip, artist)
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

  # The source's own separators, so an artist field that already leads the
  # title can be removed before the bracketed upload noise is.
  def self.normalize_title(title, artist)
    cleaned = title
    if artist.present?
      leading_artist = Regexp.new("\\A\\s*#{Regexp.escape(artist)}\\s*[-–—|:]\\s*", Regexp::IGNORECASE)
      cleaned = cleaned.sub(leading_artist, "")
    end

    cleaned = cleaned.gsub(TITLE_NOISE, " ").squish
    cleaned.presence || title
  end
  private_class_method :normalize_title

  def lyrics
    return plain_lyrics.strip if plain_lyrics.present?

    parse_synced_lyrics
  end

  def source_url
    "https://lrclib.net/api/get/#{id}"
  end

  def printable?
    !instrumental && lyrics.present?
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
