class LyricsController < ApplicationController
  # Tests inject a fake source client through this seam.
  class_attribute :lrc_lib_client_factory, default: -> { LrcLibClient.new }

  rescue_from ActiveRecord::RecordNotFound, with: :lyric_not_found

  def new
    @lyric = Lyric.new
    @songbook = songbook_context
  end

  def create
    @songbook = songbook_context

    creation = LyricPageCreation.new(
      attributes: lyric_params,
      catalog_token: params[:catalog_token]
    )

    unless creation.save
      @lyric = creation.lyric
      # A valid lyric whose verified metadata was rejected can only fail again
      # with the same token, so the form falls back to manual entry.
      @catalog_token = @lyric.errors.empty? ? nil : params[:catalog_token]
      flash.now[:alert] = lyric_failure_message(@lyric)
      return render :new, status: :unprocessable_content
    end

    @lyric = creation.lyric
    session[:generated_lyric_token] = @lyric.token
    redirect_to destination_for(@lyric)
  end

  def search
    @lyric = Lyric.new
    @songbook = songbook_context
    @query = params[:query].to_s.strip

    search = SongSearch.new(query: @query)

    if search.perform(client: lrc_lib_client)
      @results = search.results
      @search_status = search.empty? ? t("lyrics.search.empty") : t("lyrics.search.status", count: @results.size)
      render :new, status: :ok
    else
      @search_error = search.errors.first&.message
      render :new, status: :unprocessable_content
    end
  rescue LrcLibClient::ServiceError
    @search_error = t("songs.errors.service")
    render :new, status: :service_unavailable
  end

  def select
    @query = params[:query].to_s.strip
    @songbook = songbook_context

    lookup = SongLookup.new
    lookup.perform(params[:result_id], client: lrc_lib_client)

    @lyric = lookup.lyric
    @loaded_status = t("lyrics.status.loaded")
    @catalog_token = lookup.catalog_token

    render :new, status: :ok
  rescue LrcLibClient::NotFoundError
    render_select_error(t("songs.errors.unavailable"), :unprocessable_content)
  rescue LrcLibClient::ServiceError
    render_select_error(t("songs.errors.service"), :service_unavailable)
  end

  def show
    @lyric = Lyric.renew_retention!(params[:token])
    @generated_page_key = @lyric.token if session.delete(:generated_lyric_token) == @lyric.token
  end

  private

  # Adding a song keeps the set in the URL, so the entry form, the search
  # results, and the select buttons all carry it without any session state. An
  # unknown or expired token simply means the visitor generates a single page.
  def songbook_context
    return if params[:songbook].blank?

    Songbook.active.find_by(token: params[:songbook])
  end

  def destination_for(lyric)
    return lyric unless @songbook

    # The song that turns a one-song songbook into a set is the moment the set
    # exists, and the only moment the creation event reports.
    was_a_set = @songbook.a_set?
    @songbook.append!(lyric)
    remember_created_songbook(@songbook, origin: "add_song") unless was_a_set

    @songbook
  end

  def lrc_lib_client
    @lrc_lib_client ||= self.class.lrc_lib_client_factory.call
  end

  def lyric_params
    params.require(:lyric).permit(:title, :artist, :lyrics)
  end

  def lyric_failure_message(lyric)
    return t("lyrics.errors.blank") if lyric.errors[:lyrics].any?
    return lyric.errors.full_messages.to_sentence if lyric.errors.any?

    t("lyrics.errors.metadata")
  end

  def lyric_not_found
    redirect_to root_path, alert: t("lyrics.errors.expired")
  end

  def render_select_error(message, status)
    @lyric = Lyric.new
    @catalog_token = nil
    @search_error = message

    render :new, status: status
  end
end
