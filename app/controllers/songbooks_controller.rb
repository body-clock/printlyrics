class SongbooksController < ApplicationController
  # A session holds a few sheets, not a catalog, and the set is built from
  # browser-supplied tokens, so the request is bounded rather than trusted.
  MAX_SONGS = 25

  rescue_from ActiveRecord::RecordNotFound, with: :songbook_not_found

  def create
    lyrics = requested_lyrics
    return songbook_not_found if lyrics.empty?

    songbook = Songbook.start_with(*lyrics)

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
  end

  def show
    @songbook = Songbook.renew_retention!(params[:token])
    @generated_page_key = generated_page_key
  end

  def destroy_song
    @songbook = Songbook.active.find_by!(token: params[:token])
    @songbook.remove!(Lyric.find_by!(token: params[:lyric_token]))

    redirect_to @songbook
  end

  private

  # The request order is the set order, so this resolves tokens against active
  # pages and drops anything unknown, expired, or repeated without disturbing
  # the order that survived. One sheet or several arrive the same way.
  def requested_lyrics
    tokens = Array(params[:lyric_tokens].presence || params[:lyric_token])
      .map(&:to_s)
      .uniq
      .first(MAX_SONGS)
    by_token = Lyric.active.where(token: tokens).index_by(&:token)

    tokens.filter_map { |token| by_token[token] }
  end

  # The generation event belongs to the page that was just made, so it follows
  # the visitor here instead of disappearing with the single-page redirect.
  def generated_page_key
    token = session.delete(:generated_lyric_token)
    token if token && @songbook.lyrics.exists?(token: token)
  end

  def songbook_not_found
    redirect_to root_path, alert: t("songbooks.errors.expired")
  end
end
