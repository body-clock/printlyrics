class SongbooksController < ApplicationController
  allow_unauthenticated_access only: %i[create show destroy_song shared]
  rescue_from ActiveRecord::RecordNotFound, with: :songbook_not_found

  def create
    lyrics = requested_lyrics
    return songbook_not_found if lyrics.empty?
    return redirect_to(save_songbooks_path, alert: limit_message) unless can_create_songbook?

    songbook = Songbook.start_with(*lyrics, user: current_user, visitor_key: songbook_visitor_key)
    session[:songbooks_created_on] = Date.current.iso8601 unless current_user

    # The visitor picked more songs than a free book holds. They get the ones they
    # picked, in order, and the page they land on says why the last are missing.
    if @songs_cut_by_plan
      flash[:notice] = t("songbooks.notices.song_limit", limit: Songbook::FREE_SONG_LIMIT)
    end

    # This action gathers sheets the visitor already made, so a set that is
    # already complete here came from the offer. Continuing to add a song starts
    # a one-song draft instead, and only becomes a set later.
    remember_created_songbook(songbook, origin: "offer")

    # Accepting the offer is the offer's own answer, so the panel must not make
    # it again the next time the visit returns to it — the visit has just put
    # its sheets in a songbook, whether it gathered them here or went on to add
    # another song to the draft this created.
    visit.answer_offer!

    # "Add another song" is a request to keep adding, so it continues into the
    # entry form instead of stopping at a set of one. Anything else — including
    # the offer that gathers sheets a visitor already made — wants the set it
    # just created. Only this one value is honoured, so the parameter cannot
    # send anyone anywhere else.
    if params[:then] == "add_song"
      redirect_to root_path(songbook: songbook.token)
    else
      redirect_to songbook
    end
  rescue Songbook::StorageLimitReached
    redirect_to save_songbooks_path, alert: limit_message
  end

  def show
    @songbook = Songbook.active.find_by!(token: params[:token])
    return request_authentication if @songbook.user_id.present? && current_user.nil?
    raise ActiveRecord::RecordNotFound if @songbook.user_id.present? && @songbook.user_id != current_user.id
    @songbook = Songbook.renew_retention!(params[:token])
    @can_edit_songbook = true
    @can_manage_sharing = @songbook.user_id.present?
    @premium_songbook = @can_manage_sharing && current_user.premium?
    @can_enable_sharing = @premium_songbook
    @share_url = shared_songbook_url(@songbook.share_token) if @songbook.share_token.present?

    @generated_page_key = generated_page_key
    @created_songbook = created_songbook
    remember_visit_sheet(@generated_page_key)
  end


  def share
    @songbook = Songbook.active.find_by!(token: params[:token])
    return request_authentication if @songbook.user_id.present? && current_user.nil?
    raise ActiveRecord::RecordNotFound unless @songbook.user_id.present? && @songbook.user_id == current_user&.id
    return redirect_to save_songbooks_path, alert: t("songbooks.errors.premium_sharing") unless current_user.premium?

    if @songbook.share_token.blank?
      @songbook.enable_sharing!
      session[:analytics_page_responses] = { "Songbook Share Link Created" => SecureRandom.hex(16) }
    end
    redirect_to @songbook
  end

  def revoke_share
    @songbook = Songbook.active.find_by!(token: params[:token])
    return request_authentication if @songbook.user_id.present? && current_user.nil?
    raise ActiveRecord::RecordNotFound unless @songbook.user_id.present? && @songbook.user_id == current_user&.id

    if @songbook.revoke_sharing!
      session[:analytics_page_responses] = { "Songbook Share Link Revoked" => SecureRandom.hex(16) }
    end
    redirect_to @songbook
  end

  def shared
    @songbook = Songbook.active.find_by!(share_token: params[:share_token])
    raise ActiveRecord::RecordNotFound unless @songbook.sharing_active?

    @songbook = Songbook.renew_retention!(@songbook.token)
    @can_edit_songbook = false
    @can_manage_sharing = false
    @analytics_page_responses = { "Shared Songbook Opened" => SecureRandom.hex(16) }
    render :show
  end

  def destroy_song
    @songbook = Songbook.active.find_by!(token: params[:token])
    return request_authentication if @songbook.user_id.present? && current_user.nil?
    raise ActiveRecord::RecordNotFound if @songbook.user_id.present? && @songbook.user_id != current_user.id

    @songbook.remove!(Lyric.find_by!(token: params[:lyric_token]))

    redirect_to @songbook
  end

  private

  def can_create_songbook?
    if current_user
      current_user.can_create_songbook?
    else
      session[:songbooks_created_on] != Date.current.iso8601
    end
  end

  # A guest is refused by a per-day rule they can leave behind by making an account;
  # an account is refused by what it may keep. What either can do about it depends on
  # whether this host can sell anything, which is the predicate the saving page reads
  # before rendering the plans as controls.
  def limit_message
    return t("songbooks.errors.guest_limit") if current_user.nil?

    t(StripeGateway.configured? ? "songbooks.errors.storage_limit_available" : "songbooks.errors.storage_limit",
      limit: User::FREE_SONGBOOK_LIMIT)
  end

  def songbook_visitor_key
    session[:songbook_visitor_key] ||= SecureRandom.uuid
  end

  # The request order is the set order, so this resolves tokens against active
  # pages and drops anything unknown, expired, or repeated without disturbing the
  # order that survived. One sheet or several arrive the same way, and a request
  # that asks for more than this application will take is cut to size: first by the
  # guard every request meets, then by the limit the account's plan sets, which is
  # the cut the visitor is told about.
  def requested_lyrics
    tokens = Array(params[:lyric_tokens].presence || params[:lyric_token])
      .map(&:to_s)
      .uniq
      .first(Songbook::REQUEST_LIMIT)
    by_token = Lyric.active.where(token: tokens).index_by(&:token)
    lyrics = tokens.filter_map { |token| by_token[token] }
    limit = Songbook.song_limit_for(current_user)
    return lyrics if limit.nil? || lyrics.size <= limit

    @songs_cut_by_plan = true
    lyrics.first(limit)
  end

  # The generation event belongs to the page that was just made, so it follows
  # the visitor here instead of disappearing with the single-page redirect.
  def generated_page_key
    token = session.delete(:generated_lyric_token)
    token if token && @songbook.lyrics.exists?(token: token)
  end

  # The creation event reports a set that came into being, not a row that was
  # inserted, and it carries how the set was started. It follows the same
  # one-shot session flag as a generation, so it fires on the visit that crossed
  # the threshold and never on a later one.
  def created_songbook
    origin = session.delete(:created_songbook_origin)
    return unless session.delete(:created_songbook_token) == @songbook.token

    { size: @songbook.entries.size, origin: origin }
  end

  def songbook_not_found
    redirect_to root_path, alert: t("songbooks.errors.expired")
  end
end
