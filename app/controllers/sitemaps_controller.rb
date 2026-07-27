class SitemapsController < ApplicationController
  def show
    xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |document|
      document.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        document.url do
          document.loc(root_url)
        end
      end
    end

    render xml: xml.to_xml
  end
end
