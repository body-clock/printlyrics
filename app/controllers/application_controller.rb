class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # What this visit knows about its own sheets, held in the session: the sheets
  # it generated, and whether it has answered the songbook offer. Every tab of
  # the visit reads the same list, and the offer is rendered from it rather than
  # revealed by script, so a page the browser restores still carries the offer
  # it was rendered with. See app/models/visit.rb.
  def visit
    @visit ||= Visit.new(session)
  end
  helper_method :visit

  private

  # A sheet this visit just made joins the visit, wherever the generation landed:
  # its own page, or the set it was added to. It is the same event from the
  # visitor's side and it feeds the count the sheet events carry.
  def remember_visit_sheet(page_key)
    visit.record_sheet(page_key)
  end

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
