# What the current visit knows about its own sheets, held in the session.
#
# The visit is one browser session, not one tab. A set of sheets belongs to a
# sitting, and a visitor who prints a sheet in one tab and searches for the next
# song in another is still assembling one packet; a list per tab can only ever
# offer that tab's handful.
#
# The session is also the right place for the tokens. They stay encrypted in the
# session cookie, they are gone when the browser session is, and they are never
# left where a second visitor on the same machine could be offered another
# person's lyrics as a set.
#
# The window is Umami's own: a visit expires after 30 minutes of quiet there, so
# a list older than that belongs to a different visit and the count that rides
# on `page_count_in_session` describes the visit the destination files the event
# under.
#
# docs/measurement-contract.md owns the events and what may travel.
class Visit
  # The sheet list, the moment it was last touched, and whether this visit has
  # answered the songbook offer. One key, because the three belong together and
  # a visit that lapses forgets all of it.
  SESSION_KEY = :visit

  WINDOW_SECONDS = 30 * 60
  SHEETS_BEFORE_OFFER = 2

  # A lambda so tests can move the clock instead of waiting.
  def initialize(session, clock: -> { Time.current })
    @session = session
    @clock = clock
  end

  # The sheets this visit generated, in generation order, oldest first. A list
  # that lapsed is a different visit's, so this reads as empty rather than
  # expiring what is stored: the next write replaces it.
  def sheets
    return [] unless current?

    Array(stored["sheets"]).grep(String)
  end

  def sheet_count = sheets.size

  # A generated sheet joins the visit. Order is the set's order and membership
  # is what keeps a replayed page from counting twice, so a token already in the
  # list moves nothing. The cap keeps the newest sheets, which is what a set can
  # hold.
  def record_sheet(token)
    return if token.blank?

    list = sheets
    return if list.include?(token)

    write(list + [ token ], answered: offer_answered?)
  end

  # Worth offering once the visit holds a second sheet, and one answer either
  # way settles it for the rest of the visit.
  def offer_pending? = sheet_count >= SHEETS_BEFORE_OFFER && !offer_answered?

  def offer_answered? = current? && stored["offer_answered"] == true

  def answer_offer! = write(sheets, answered: true)

  # Identifies the response an offer was rendered in. It is what keeps a
  # snapshot Turbo replays — the same markup, the same key — from reporting the
  # offer twice.
  def offer_key
    @offer_key ||= SecureRandom.hex(8)
  end

  private

  def stored
    raw = @session[SESSION_KEY]
    raw.is_a?(Hash) ? raw : {}
  end

  def current?
    touched_at = stored["at"].to_i
    touched_at.positive? && @clock.call.to_i - touched_at <= WINDOW_SECONDS
  end

  def write(sheets, answered:)
    @session[SESSION_KEY] = {
      "sheets" => sheets.last(Songbook::MAX_SONGS),
      "at" => @clock.call.to_i,
      "offer_answered" => answered
    }
  end
end
