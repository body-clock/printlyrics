class SitemapsController < ApplicationController
  def show
    xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |document|
      document.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        [ root_url, print_lyrics_on_one_page_url ].each do |location|
          document.url do
            document.loc(location)
          end
        end
      end
    end

    render xml: xml.to_xml
  end
end
