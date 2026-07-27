module LyricExtractors
  class AzLyrics < Base
    TITLE_SUFFIX = /\s+Lyrics\s+\|\s+AZLyrics\.com\z/i

    def parse(html)
      page = document(html)
      lyric_node = page.css("div:not([class]):not([id])").max_by do |node|
        text_with_breaks(node).length
      end
      lyrics = lyric_node && text_with_breaks(lyric_node)
      raise LyricExtractor::ParseError if lyrics.blank?

      artist, title = metadata(page)
      LyricExtractor::Extraction.new(title: title, artist: artist, lyrics: lyrics)
    end

    private

    def metadata(page)
      value = page.at_css("title")&.text.to_s.sub(TITLE_SUFFIX, "").strip
      artist, title = value.split(/\s+-\s+/, 2)

      [ artist.presence, title.presence ]
    end
  end
end
