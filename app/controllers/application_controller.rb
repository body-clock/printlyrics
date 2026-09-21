class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Records that this visit turned a songbook into a set, and which route did it:
  # the offer that gathers sheets already made, or a song added to a set. Both
  # cross the same threshold, so both report the moment it happened rather than
  # the insert that started the draft.
  def remember_created_songbook(songbook, origin:)
    return unless songbook.a_set?

    session[:created_songbook_token] = songbook.token
    session[:created_songbook_origin] = origin
  end
end
