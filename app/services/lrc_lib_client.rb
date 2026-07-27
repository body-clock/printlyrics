class LrcLibClient
  class Error < StandardError; end
  class NotFoundError < Error; end
  class ServiceError < Error; end

  Result = Data.define(
    :id,
    :title,
    :artist,
    :album,
    :duration,
    :plain_lyrics,
    :synced_lyrics,
    :instrumental
  ) do
    def lyrics
      return plain_lyrics.strip if plain_lyrics.present?

      synced_lyrics.to_s.lines.filter_map do |line|
        text = line.sub(/\A(?:\[[^\]]+\])+\s*/, "").strip
        text if text.present?
      end.join("\n")
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
  end

  SEARCH_LIMIT = 5

  def initialize(connection: nil)
    @connection = connection || Faraday.new(
      url: "https://lrclib.net",
      headers: {
        "Accept" => "application/json",
        "User-Agent" => "PrintLyrics/1.0 (+https://printlyrics.app)"
      }
    ) do |faraday|
      faraday.options.timeout = 10
      faraday.options.open_timeout = 5
      faraday.adapter Faraday.default_adapter
    end
  end

  def search(query)
    rows = request_json("/api/search", { q: query })
    raise ServiceError unless rows.is_a?(Array)

    rows
      .filter_map { |row| build_result(row) }
      .select(&:printable?)
      .uniq(&:deduplication_key)
      .first(SEARCH_LIMIT)
  end

  def find(id)
    id = Integer(id, exception: false)
    raise NotFoundError unless id&.positive?

    result = build_result(request_json("/api/get/#{id}", not_found: true))
    raise NotFoundError unless result&.printable?

    result
  end

  private

  def request_json(path, params = {}, not_found: false)
    response = @connection.get(path, params)
    raise NotFoundError if not_found && response.status == 404
    raise ServiceError unless response.success?

    JSON.parse(response.body)
  rescue JSON::ParserError, Faraday::Error, SocketError, SystemCallError
    raise ServiceError
  end

  def build_result(row)
    return unless row.is_a?(Hash)

    id = Integer(row["id"], exception: false)
    title = row["trackName"].to_s.strip
    artist = row["artistName"].to_s.strip
    return unless id&.positive? && title.present? && artist.present?

    Result.new(
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
end
