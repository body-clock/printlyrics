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

  # What the edit budget above cannot reach: the source's own spelling of a word
  # the visitor spelled another way — its "Taio Cruz" for "Taio Cruise", which
  # is three edits from the visitor's word and no prefix of it. One such word
  # per record is forgiven and no more, because two words that only start alike
  # are otherwise a different song that happens to be spelled the same way.
  VARIANT_PREFIX = 3
  VARIANT_LIMIT = 1

  # A token shorter than this is too weak to carry meaning on its own.
  MIN_SIGNIFICANT_LENGTH = 2

  # A query with this many meaningful words may be missing one the record does
  # not carry.
  SLACK_FROM = 4

  # The ladder is bounded: every attempt is another round trip to a source that
  # rate-limits, and a long query could otherwise ask a dozen times. The
  # precise attempts come first and the broadest tail is cut, not reordered.
  ATTEMPT_LIMIT = 10

  # Adjacent words, so a title and an artist the visitor put last are still
  # asked as a pair; only the first pair is not enough ("seven lucas graham").
  BIGRAM_LIMIT = 4

  # Every significant word on its own, longest first, because the word that
  # names the song is often the one the earlier ladder never reached. The four
  # longest are the most distinctive; asking all of them would be a query per
  # word.
  SINGLE_LIMIT = 4

  # A query minus one word, because the source requires every token: the word
  # the source cannot match is often one the visitor misspelled, and dropping it
  # leaves words the record does carry ("ashley kitchen light" for "ashley
  # mcbride kitchen light on"). Four covers the usual title/artist query; a
  # longer query drops its trailing qualifier first, because that is the word a
  # visitor most often appends.
  DROP_LIMIT = 4

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
    return false if significant_tokens.empty?

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

  # A word the source spells its own way, past what the edit budget reaches.
  # Both tokens need enough length to carry a stem before the stems are
  # compared, so a short word cannot be forgiven on three shared letters alone.
  def self.variant?(left, right)
    return false if left.length < TYPO_LENGTH || right.length < TYPO_LENGTH

    left[0, VARIANT_PREFIX] == right[0, VARIANT_PREFIX]
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

    ladder = []
    append(ladder, :keywords, { q: cleaned })
    append(ladder, :keywords, { q: significant_tokens.join(" ") })

    if (title, artist = field_parts)
      append(ladder, :fields, { track_name: title, artist_name: artist })
    end

    append(ladder, :keywords, { q: significant_tokens.join }) if (2..3).cover?(significant_tokens.size)

    # The one most distinctive word first: it is often the artist or the noun
    # in the title, and the source answers a single word with a list that
    # scoring can filter. Asking it before the pairs keeps it inside the
    # attempt and time budget, where it is the only chance for queries whose
    # other words are misspelled.
    longest_tokens(1).each { |token| append(ladder, :keywords, { q: token }) }

    significant_tokens.each_cons(2).first(BIGRAM_LIMIT).each do |pair|
      append(ladder, :keywords, { q: pair.join(" ") })
    end

    if significant_tokens.size > 2
      drop_indices.each do |index|
        append(ladder, :keywords, { q: without(index).join(" ") })
      end
    end

    longest_tokens(SINGLE_LIMIT).each { |token| append(ladder, :keywords, { q: token }) }

    ladder.first(ATTEMPT_LIMIT)
  end

  def longest_tokens(limit)
    significant_tokens.sort_by { |token| [ -self.class.fold(token).length, token ] }.first(limit)
  end

  # A long query is usually the song plus a qualifier ("acoustic", "demo"), so
  # the last word is dropped first, then the words that most often start the
  # title or artist. A four-word query has a drop for every word.
  def drop_indices
    return (0...significant_tokens.size).to_a if significant_tokens.size <= DROP_LIMIT

    [ significant_tokens.size - 1, 0, 1, 2 ]
  end

  def without(index)
    tokens = significant_tokens.dup
    tokens.delete_at(index)
    tokens
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
    title_tokens = self.class.tokenize(result.title).map { |token| self.class.fold(token) }
    return significant_tokens.size if compounds?(title_tokens)

    matches = significant_tokens.map do |token|
      folded = self.class.fold(token)
      if haystack.any? { |candidate| self.class.same_word?(folded, candidate) }
        :word
      elsif haystack.any? { |candidate| self.class.variant?(folded, candidate) }
        :variant
      end
    end

    matches.count(:word) + [ matches.count(:variant), VARIANT_LIMIT ].min
  end

  # A title the source stores as one word and the visitor typed as two, which
  # the per-word comparison can never cover: "margarita ville" against
  # "Margaritaville". Only the title is compared: the artist is not the song,
  # and "back street" matching the artist "Backstreet Boys" would show a
  # different song. Both sides are folded, and the whole query has to form the
  # title, so two words that merely start alike are still a different title.
  def compounds?(title_tokens)
    return false if significant_tokens.size < 2

    joined = significant_tokens.map { |token| self.class.fold(token) }.join
    return false if joined.empty?

    title_tokens.include?(joined) || title_tokens.join == joined
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
