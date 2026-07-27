module LyricExtractors
  class Base
    private

    def document(html)
      Nokogiri::HTML5(html)
    rescue Nokogiri::SyntaxError
      raise LyricExtractor::ParseError
    end

    def text_with_breaks(node)
      fragment = node.dup
      fragment.xpath(".//text()").each do |text_node|
        text_node.content = text_node.content
          .sub(/\A[ \t]*\n[ \t]*/, "")
          .sub(/[ \t]*\n[ \t]*\z/, "")
      end
      fragment.css("br").each { |break_node| break_node.replace("\n") }
      clean(fragment.text)
    end

    def clean(text)
      text
        .to_s
        .gsub("\u00A0", " ")
        .lines
        .map(&:strip)
        .join("\n")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end
  end
end
