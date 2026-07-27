module LyricExtractors
  class Genius < Base
    TITLE_SUFFIX = /\s+Lyrics\s+\|\s+Genius Lyrics\z/i

    def parse(html)
      page = document(html)
      containers = page.css('[data-lyrics-container="true"]')
      raise LyricExtractor::ParseError if containers.empty?

      lyric_sections = containers.filter_map do |container|
        fragment = container.dup
        fragment.css("[data-exclude-from-selection]").remove
        text = text_with_breaks(fragment)
        text if text.present?
      end
      raise LyricExtractor::ParseError if lyric_sections.empty?

      artist, title = metadata(page)
      LyricExtractor::Extraction.new(
        title: title,
        artist: artist,
        lyrics: lyric_sections.join("\n\n")
      )
    end

    private

    def metadata(page)
      value = page.at_css('meta[property="og:title"]')&.[]("content").to_s
      value = value.gsub("\u00A0", " ").sub(TITLE_SUFFIX, "").strip
      artist, title = value.split(/\s+[–—]\s+/, 2)

      [ artist.presence, title.presence ]
    end
  end
end
