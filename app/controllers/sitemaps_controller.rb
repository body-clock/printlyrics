class SitemapsController < ApplicationController
  def show
    xml = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |document|
      document.urlset(xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9") do
        [ root_url, print_lyrics_on_one_page_url ].each do |location|
          document.url do
            document.loc(location)
          end
        end

        song_page_count.times do |index|
          page = index + 1
          document.url do
            document.loc(page == 1 ? songs_url : songs_url(page: page))
          end
        end

        Song.indexable.find_each do |song|
          document.url do
            document.loc(song_url(song))
            document.lastmod(song.updated_at.iso8601)
          end
        end
      end
    end

    render xml: xml.to_xml
  end

  private

  def song_page_count
    [ (Song.indexable.count.to_f / SongsController::PAGE_SIZE).ceil, 1 ].max
  end
end
