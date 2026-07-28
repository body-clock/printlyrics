class LyricsController < ApplicationController
  attr_writer :lrc_lib_client

  rescue_from ActiveRecord::RecordNotFound, with: :lyric_not_found

  def new
    @lyric = Lyric.new
  end

  def create
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

    search = SongSearch.new(query: @query)
    search.perform(client: lrc_lib_client)

    @results = search.results || []
    @search_error = search.error_message
    @search_status = "#{helpers.pluralize(@results.size, "match")} found. Choose a song." if search.success?

    render :new, status: search.http_status
  end

  def select
    @query = params[:query].to_s.strip

    lookup = SongLookup.new
    lookup.perform(params[:result_id], client: lrc_lib_client)

    @lyric = lookup.lyric || Lyric.new
    @loaded_status = "Lyrics loaded. Review and edit them before generating your print page." if lookup.success?
    @search_error = lookup.error

    render :new, status: lookup.http_status
  end

  def show
    @lyric = Lyric.active.find_by!(token: params[:token])
    @lyric.renew_retention!
  end

  private

  def lrc_lib_client
    @lrc_lib_client ||= LrcLibClient.new
  end

  def lyric_params
    params.require(:lyric).permit(:title, :artist, :lyrics, :source_url)
  end

  def lyric_not_found
    redirect_to root_path, alert: "That lyric page expired or wasn't found"
  end
end
