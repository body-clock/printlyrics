class LyricsController < ApplicationController
  # Tests inject a fake source client through this seam.
  class_attribute :lrc_lib_client_factory, default: -> { LrcLibClient.new }

  rescue_from ActiveRecord::RecordNotFound, with: :lyric_not_found

  def new
    prepare_entry_context
    @lyric = @revision ? Lyric.new(@revision.attributes.slice("title", "artist", "lyrics")) : Lyric.new
    @entry_response = @revision ? "revision" : "initial"
    @entry_mode = @revision ? "paste" : "find"
  end

  def create
    prepare_entry_context

    creation = LyricPageCreation.new(
      attributes: lyric_params,
      catalog_token: params[:catalog_token]
    )

    unless creation.save
      @lyric = creation.lyric
      @entry_response = "validation"
      @entry_mode = "paste"
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
    prepare_entry_context
    @lyric = entry_draft
    @entry_response = "search"
    @entry_mode = "find"
    @query = params[:query].to_s.strip

    search = SongSearch.new(query: @query)

    if search.perform(client: lrc_lib_client)
      @results = search.results

      if search.empty?
        @lyric.title = @query if @lyric.title.blank?
        @search_status = t("lyrics.search.empty")
      else
        @search_status = t("lyrics.search.status", count: @results.size)
      end

      render :new, status: :ok
    else
      @search_error = search.errors.first&.message
      render :new, status: :unprocessable_content
    end
  rescue LrcLibClient::ServiceError => error
    report_source_failure(error)
    @search_error = t("songs.errors.service")
    render :new, status: :service_unavailable
  end

  def select
    @query = params[:query].to_s.strip
    prepare_entry_context

    lookup = SongLookup.new
    lookup.perform(params[:result_id], client: lrc_lib_client)

    @lyric = lookup.lyric
    @loaded_status = t("lyrics.status.loaded")
    @catalog_token = lookup.catalog_token
    @entry_response = "selected"
    @entry_mode = "paste"

    render :new, status: :ok
  rescue LrcLibClient::NotFoundError
    render_select_error(t("songs.errors.unavailable"), :unprocessable_content)
  rescue LrcLibClient::ServiceError => error
    # The search itself answered; only the lyrics lookup failed. Saying the
    # search is down here is both wrong and what hides a recovered search behind
    # a message the visitor reads as an outage.
    report_source_failure(error)
    render_select_error(t("songs.errors.load_service"), :service_unavailable, retry_result_id: params[:result_id])
  end

  def show
    @lyric = Lyric.renew_retention!(params[:token])
    if session[:generated_lyric_token] == @lyric.token
      @generated_page_key = @lyric.token
      session.delete(:generated_lyric_token)
    end
    remember_visit_sheet(@generated_page_key)

    # The second sheet is where the songbook offer appears, so the account ask
    # waits: two competing prompts on one page would make neither one clear.
    # Once the offer is settled, a later sheet can ask again.
    @account_prompt = account_prompt_for?(
      @generated_page_key.present? || visit.sheets.include?(@lyric.token)
    ) && !visit.offer_pending?
  end

  private

  def prepare_entry_context
    @songbook = songbook_context
    @revision = Lyric.active.find_by!(token: params[:revision]) if params[:revision].present?
    @entry_size = params[:size].presence_in(%w[s m l xl])
    @entry_columns = params[:columns].to_s.presence_in(%w[1 2])
  end

  def entry_draft
    params[:lyric].present? ? Lyric.new(lyric_params) : Lyric.new
  end

  # Adding a song keeps the set in the URL, so the entry form, the search
  # results, and the select buttons all carry it without any session state. An
  # unknown or expired token simply means the visitor generates a single page.
  def songbook_context
    return if params[:songbook].blank?

    Songbook.active.find_by(token: params[:songbook])
  end

  def destination_for(lyric)
    return lyric if @revision || !@songbook

    # The song that turns a one-song songbook into a set is the moment the set
    # exists, and the only moment the creation event reports.
    was_a_set = @songbook.a_set?
    @songbook.append!(lyric)
    remember_created_songbook(@songbook, origin: "add_song") unless was_a_set

    @songbook
  rescue Songbook::LimitReached
    flash[:alert] = t("songbooks.errors.full", limit: Songbook::MAX_SONGS)
    lyric
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

  def render_select_error(message, status, retry_result_id: nil)
    @lyric = entry_draft
    @lyric.title = @query if @lyric.title.blank?
    @entry_response = "search"
    @entry_mode = "find"
    @catalog_token = nil
    @search_error = message
    @retry_result_id = retry_result_id

    render :new, status: status
  end

  # A source failure is handled copy for the visitor, and an outage the source
  # owns is not a defect in this app: it becomes an Insights event, so a busy
  # or hung LRCLIB is visible without opening a fault nobody can act on. A
  # failure the client did not anticipate still opens one. Honeybadger receives
  # the endpoint, status, and the source's own explanation; the visitor's query
  # never leaves this method.
  def report_source_failure(error)
    Rails.logger.warn("LRCLIB unavailable during lyrics##{action_name}: #{error.message}")
    detail = {
      action: action_name,
      endpoint: error.endpoint,
      status: error.status,
      attempts: error.attempts,
      detail: error.detail
    }.compact

    if error.source_unavailable?
      Honeybadger.event("lrclib_source_failure", detail)
    else
      Honeybadger.notify(error, context: detail)
    end
  end
end
