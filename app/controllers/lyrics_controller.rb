class LyricsController < ApplicationController
  attr_writer :lrc_lib_client

  rescue_from ActiveRecord::RecordNotFound, with: :lyric_not_found

  def new
    @lyric = Lyric.new
  end

  def create
    creation = LyricPageCreation.new(
      attributes: lyric_params,
      catalog_token: params[:catalog_token]
    )

    unless creation.save
      @lyric = creation.lyric
      @catalog_token = params[:catalog_token]
      flash.now[:alert] = t("lyrics.errors.blank")
      return render :new, status: :unprocessable_content
    end

    @lyric = creation.lyric
    session[:generated_lyric_token] = @lyric.token
    redirect_to @lyric
  end

  def search
    @lyric = Lyric.new
    @query = params[:query].to_s.strip

    search = SongSearch.new(query: @query)
    search.perform(client: lrc_lib_client)

    @results = search.results || []
    @search_error = search.error_message
    @search_status = t("lyrics.search.status", count: @results.size) if search.success?

    render :new, status: search.http_status
  end

  def select
    @query = params[:query].to_s.strip

    lookup = SongLookup.new
    lookup.perform(params[:result_id], client: lrc_lib_client)

    @lyric = lookup.lyric || Lyric.new
    @loaded_status = t("lyrics.status.loaded") if lookup.success?
    @catalog_token = lookup.catalog_token
    @search_error = lookup.error

    render :new, status: lookup.http_status
  end

  def show
    @lyric = Lyric.active.find_by!(token: params[:token])
    @generated_page_key = @lyric.token if session.delete(:generated_lyric_token) == @lyric.token
    @lyric.renew_retention!
  end

  private

  def lrc_lib_client
    @lrc_lib_client ||= LrcLibClient.new
  end

  def lyric_params
    params.require(:lyric).permit(:title, :artist, :lyrics)
  end

  def lyric_not_found
    redirect_to root_path, alert: t("lyrics.errors.expired")
  end
end
