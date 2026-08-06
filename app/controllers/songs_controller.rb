class SongsController < ApplicationController
  PAGE_SIZE = 50

  attr_writer :lrc_lib_client

  def index
    @page = [ Integer(params[:page], exception: false).to_i, 1 ].max
    @popular_songs = @page == 1 ? Song.popular.to_a : []
    @popular_refreshed_at = @popular_songs.first&.popular_refreshed_at
    scope = Song.archive
    @total_pages = (scope.count.to_f / PAGE_SIZE).ceil
    @archive_songs = scope.limit(PAGE_SIZE).offset((@page - 1) * PAGE_SIZE)
  end

  def show
    @song = find_song
    @entry_method = catalog_entry
    return render_gone if @song.unavailable_at?

    raise ActiveRecord::RecordNotFound unless @song.indexable?
  end

  def load
    @song = find_song
    @entry_method = catalog_entry
    return render_gone if @song.unavailable_at?

    lookup = SongLookup.new
    lookup.perform(@song.source_id, client: lrc_lib_client)

    return mark_unavailable_and_render if lookup.http_status == :unprocessable_content
    return render_load_error(lookup) unless lookup.success?

    @song.refresh_from_result!(lookup.result)
    @lyric = lookup.lyric
    @catalog_token = lookup.catalog_token
    @loaded_status = t("lyrics.status.loaded")
    render "lyrics/new"
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

  def render_load_error(lookup)
    @load_error = lookup.error
    render :show, status: :service_unavailable
  end

  def lrc_lib_client
    @lrc_lib_client ||= LrcLibClient.new
  end

  def catalog_entry
    params[:entry].in?(%w[popular archive]) ? params[:entry] : "direct"
  end
end
