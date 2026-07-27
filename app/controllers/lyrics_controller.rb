class LyricsController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :lyric_not_found

  def new
    @lyric = Lyric.new
  end

  def create
    Lyric.purge_expired!
    @lyric = Lyric.new(lyric_params)
    if @lyric.save
      redirect_to @lyric
    else
      flash.now[:alert] = "Please paste your lyrics"
      render :new, status: :unprocessable_content
    end
  end

  def search
    @lyric = Lyric.new
    @query = params[:query].to_s.strip
    return render_search_error("Enter a song title or artist") if @query.blank?
    return render_search_error("Keep your search under 200 characters") if @query.length > 200

    @results = LrcLibClient.new.search(@query)
    if @results.empty?
      @search_error = "No matching songs found"
    else
      @search_status = "#{helpers.pluralize(@results.size, "match")} found. Choose a song."
    end
    render :new
  rescue LrcLibClient::ServiceError
    render_service_error
  end

  def select
    @query = params[:query].to_s.strip
    result = LrcLibClient.new.find(params[:result_id])
    @lyric = Lyric.new(
      title: result.title,
      artist: result.artist,
      lyrics: result.lyrics,
      source_url: result.source_url
    )
    @loaded_status = "Lyrics loaded. Review and edit them before generating your print page."
    render :new
  rescue LrcLibClient::NotFoundError
    @lyric = Lyric.new
    render_search_error("That song is no longer available")
  rescue LrcLibClient::ServiceError
    @lyric = Lyric.new
    render_service_error
  end

  def show
    @lyric = Lyric.active.find_by!(token: params[:token])
    @lyric.renew_retention!
  end

  private

  def render_search_error(message)
    @lyric ||= Lyric.new
    @search_error = message
    render :new, status: :unprocessable_content
  end

  def render_service_error
    @lyric ||= Lyric.new
    @search_error = "Song search is temporarily unavailable. You can still paste lyrics below."
    render :new, status: :service_unavailable
  end

  def lyric_params
    params.require(:lyric).permit(:title, :artist, :lyrics, :source_url)
  end

  def lyric_not_found
    redirect_to root_path, alert: "That lyric page expired or wasn't found"
  end
end
