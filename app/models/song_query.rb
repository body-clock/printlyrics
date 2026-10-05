# Understands what a visitor typed and judges whether a candidate is the song
# they asked for.
#
# LRCLIB's /api/search requires every token of the query to appear somewhere in
# a record, so one filler word ("lyrics", "by", "official") or one typo returns
# nothing at all — and it still answers some queries with an unrelated record.
# This object strips what the source chokes on, offers an ordered ladder of
# attempts from precise to broad, and scores every row that comes back against
# the visitor's own words before it is shown.
class SongQuery
  # Words a visitor wraps a title in. Only the edges are trimmed, so a title
  # that uses one of them in the middle keeps it.
  NOISE_WORDS = %w[
    lyrics lyric song songs music testo letra letras traducida
    official video audio hd hq remaster remastered
  ].freeze

  # Function words carry no matching signal and are the tokens a record is most
  # likely to lack.
  STOP_WORDS = %w[
    a an and are at by for from ft feat featuring i in is it me my of on prod
    that the this to with you your
  ].freeze

  BRACKETED_NOISE = /[\[(][^\])]*(?:official|lyric|audio|video|hd|hq|remaster|live|performance)[^\])]*[\])]/i
  URL = %r{https?://\S+}i

  # "Title by Artist", "Artist - Title" and the dash variants of the same idea.
  FIELD_SEPARATOR = /\A(.+?)\s+(?:by|[-–—|])\s+(.+)\z/i

  # Two tokens count as the same word when they are equal or one edit apart
  # (adjacent transpositions included), which recovers "Marroon" for "Maroon"
  # and "thtat" for "that" without a dictionary. Deliberately not a prefix
  # match: "down" is a prefix of "downey", and that is a different song.
  TYPO_LENGTH = 4
  TYPO_DISTANCE = 1

  # A token shorter than this is too weak to carry meaning on its own.
  MIN_SIGNIFICANT_LENGTH = 2

  # A query with this many meaningful words may be missing one the record does
  # not carry.
  SLACK_FROM = 4

  # What to ask the source. Every row that comes back is scored against the
  # query before it is shown: LRCLIB answers some exact queries with an
  # unrelated record, so the ask and the judgement are separate steps.
  Attempt = Data.define(:kind, :params) do
    # A stable key so the ladder never issues the same request twice.
    def request_key = [ kind, params.values ].join("\u0000")
  end

  def initialize(raw)
    @raw = raw.to_s
  end

  def blank? = tokens.empty?

  # What the visitor typed, with the wrapping a source cannot match removed.
  def cleaned = tokens.join(" ")

  # The ladder, most precise first. Callers stop at the first attempt whose rows
  # are accepted, so the common query costs one request.
  def attempts
    @attempts ||= build_attempts
  end

  def rank(results)
    results.each_with_index.sort_by { |(result, index)| [ -covered(result), index ] }.map(&:first)
  end

  def accepts?(results)
    results.any? { |result| covered(result) >= required }
  end

  # A title and an artist split out of the query, when the visitor separated
  # them. LRCLIB matches those fields more precisely than one keyword string.
  def field_parts
    return @field_parts if defined?(@field_parts)

    match = structure.match(FIELD_SEPARATOR)
    if match
      title = query_text(match[1])
      artist = query_text(match[2])
      @field_parts = [ title, artist ] if title.present? && artist.present?
    end

    @field_parts
  end

  def self.tokenize(text)
    text.to_s
      .unicode_normalize(:nfkc)
      .gsub(URL, " ")
      .gsub(BRACKETED_NOISE, " ")
      .gsub(/[’‘`´]/, "'")
      .gsub(/[“”]/, " ")
      .downcase
      .gsub(/[^\p{Alnum}'\-\s]/u, " ")
      .split
      .reject { |token| fold(token).empty? }
  end

  # Case is already folded; this drops the punctuation a source does not keep,
  # so "don't" and "dont" compare equal.
  def self.fold(token) = token.delete("'-")

  def self.same_word?(left, right)
    return true if left == right
    return false if (left.length - right.length).abs > TYPO_DISTANCE
    return false if left.length < TYPO_LENGTH || right.length < TYPO_LENGTH

    edit_distance(left, right) <= TYPO_DISTANCE
  end

  # Damerau-Levenshtein with adjacent transpositions, so "thtat" is one edit
  # from "that" rather than two.
  def self.edit_distance(left, right)
    distances = Array.new(left.length + 1) { Array.new(right.length + 1, 0) }

    (0..left.length).each { |row| distances[row][0] = row }
    (0..right.length).each { |column| distances[0][column] = column }

    (1..left.length).each do |row|
      (1..right.length).each do |column|
        cost = left[row - 1] == right[column - 1] ? 0 : 1
        distances[row][column] = [
          distances[row - 1][column] + 1,
          distances[row][column - 1] + 1,
          distances[row - 1][column - 1] + cost
        ].min

        if row > 1 && column > 1 && left[row - 1] == right[column - 2] && left[row - 2] == right[column - 1]
          distances[row][column] = [ distances[row][column], distances[row - 2][column - 2] + 1 ].min
        end
      end
    end

    distances[left.length][right.length]
  end

  private

  # Apostrophes and hyphens stay because they separate words ("blink-182");
  # `fold` removes them only for comparison.
  def tokens
    @tokens ||= strip_edge_noise(self.class.tokenize(@raw))
  end

  def significant_tokens
    @significant_tokens ||= tokens.reject { |token| stop_word?(token) || token.length < MIN_SIGNIFICANT_LENGTH }
  end

  def build_attempts
    return [] if blank?

    [].tap do |ladder|
      append(ladder, :keywords, { q: cleaned })
      append(ladder, :keywords, { q: significant_tokens.join(" ") })

      if (title, artist = field_parts)
        append(ladder, :fields, { track_name: title, artist_name: artist })
      end

      append(ladder, :keywords, { q: significant_tokens.first(2).join(" ") }) if significant_tokens.size > 2
      append(ladder, :keywords, { q: significant_tokens.first }) if significant_tokens.size > 1
    end
  end

  def append(ladder, kind, params)
    return if params.values.all?(&:blank?)

    attempt = Attempt.new(kind: kind, params: params)
    return if ladder.any? { |existing| existing.request_key == attempt.request_key }

    ladder << attempt
  end

  # In one place because every comparison in this object is against the same
  # normalization: a query token and a record's title only match if both went
  # through here.
  #
  # Only the title and the artist count. The source matches album names too, so
  # a record can come back carrying a query word from its album alone, and an
  # album is not the song the visitor asked for.
  def covered(result)
    haystack = self.class.tokenize("#{result.title} #{result.artist}").map { |token| self.class.fold(token) }

    significant_tokens.count do |token|
      folded = self.class.fold(token)
      haystack.any? { |candidate| self.class.same_word?(folded, candidate) }
    end
  end

  def required
    significant_tokens.size >= SLACK_FROM ? significant_tokens.size - 1 : significant_tokens.size
  end

  def stop_word?(token) = STOP_WORDS.include?(self.class.fold(token))

  def strip_edge_noise(list)
    list = list.dup
    list.shift while list.any? && NOISE_WORDS.include?(self.class.fold(list.first))
    list.pop while list.any? && NOISE_WORDS.include?(self.class.fold(list.last))
    list
  end

  def query_text(text) = strip_edge_noise(self.class.tokenize(text)).join(" ")

  # Punctuation is kept here so " - " is still visible to FIELD_SEPARATOR.
  def structure
    @structure ||= @raw
      .unicode_normalize(:nfkc)
      .gsub(URL, " ")
      .gsub(/[’‘`´]/, "'")
      .gsub(/[“”]/, " ")
      .gsub(/\s+/, " ")
      .strip
  end
end
