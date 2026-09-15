class SongsController < ApplicationController
  attr_writer :lrc_lib_client

  def index
    request = [ Integer(params[:page], exception: false).to_i, 1 ].max
    @total_pages = Song.indexable_page_count
    raise ActiveRecord::RecordNotFound if request > @total_pages

    @page = request
    scope = Song.indexable.order(:artist, :title, :source_id)
    @songs = scope.limit(Song::PAGE_SIZE).offset((@page - 1) * Song::PAGE_SIZE)
  end

  def show
    @song = find_song
    return render_gone if @song.unavailable_at?

    raise ActiveRecord::RecordNotFound unless @song.indexable?
  end

  def load
    @song = find_song
    return render_gone if @song.unavailable_at?

    lookup = SongLookup.new
    lookup.perform(@song.source_id, client: lrc_lib_client)

    @song.refresh_from_result!(lookup.result)
    @lyric = lookup.lyric
    @catalog_token = lookup.catalog_token
    @loaded_status = t("lyrics.status.loaded")
    render "lyrics/new"
  rescue LrcLibClient::NotFoundError
    mark_unavailable_and_render
  rescue LrcLibClient::ServiceError
    render_load_error
  end

  private

  def find_song
    Song.find_by!(slug: params[:slug])
  end

  def render_gone
    render :gone, status: :gone
  end

  def mark_unavailable_and_render
    @song.mark_unavailable!
    render_gone
  end

  def render_load_error
    @load_error = t("songs.errors.service")
    render :show, status: :service_unavailable
  end

  def lrc_lib_client
    @lrc_lib_client ||= LrcLibClient.new
  end
end
