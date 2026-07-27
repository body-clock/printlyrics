class LyricsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :lyric_not_found

  def new
    @lyric = Lyric.new
  end

  def create
    return fetch_lyrics if params[:fetch].present?

    Lyric.purge_expired!
    @lyric = Lyric.new(lyric_params)
    if @lyric.save
      redirect_to @lyric
    else
      flash.now[:alert] = "Please paste your lyrics"
      render :new, status: :unprocessable_content
    end
  end

  def show
    @lyric = Lyric.active.find_by!(token: params[:token])
    @lyric.renew_retention!
  end

  private

  def fetch_lyrics
    result = LyricExtractor.new.extract(params[:url])
    @source_url = params[:url]
    @lyric = Lyric.new(title: result.title, artist: result.artist, lyrics: result.lyrics, source_url: @source_url)
    flash.now[:notice] = "Lyrics fetched. Review and edit them before generating your print page."
    render :new
  rescue LyricExtractor::UnsupportedSiteError
    redirect_to root_path, alert: "Couldn't fetch lyrics from that URL"
  rescue LyricExtractor::FetchError
    redirect_to root_path, alert: "Couldn't reach that page"
  rescue LyricExtractor::ParseError
    redirect_to root_path, alert: "Couldn't find lyrics on that page"
  end

  def lyric_params
    params.require(:lyric).permit(:title, :artist, :lyrics, :source_url)
  end

  def lyric_not_found
    redirect_to root_path, alert: "That lyric page expired or wasn't found"
  end
end
