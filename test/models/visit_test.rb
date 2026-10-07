require "test_helper"

class VisitTest < ActiveSupport::TestCase
  # A clock the test moves, so the window is exercised without waiting.
  class Clock
    attr_accessor :now

    def initialize(now) = @now = now

    def call = @now
  end

  test "records the visit's sheets in generation order" do
    visit = build_visit

    visit.record_sheet("first")
    visit.record_sheet("second")

    assert_equal %w[first second], visit.sheets
    assert_equal 2, visit.sheet_count
  end

  test "a sheet the visit already holds moves nothing" do
    visit = build_visit

    visit.record_sheet("first")
    visit.record_sheet("second")
    visit.record_sheet("first")

    assert_equal %w[first second], visit.sheets
  end

  test "records nothing for a sheet with no token" do
    visit = build_visit

    visit.record_sheet(nil)
    visit.record_sheet("")

    assert_equal [], visit.sheets
  end

  test "keeps the newest sheets a set can hold" do
    visit = build_visit

    (Songbook::MAX_SONGS + 3).times { |index| visit.record_sheet("sheet-#{index}") }

    assert_equal Songbook::MAX_SONGS, visit.sheet_count
    assert_equal "sheet-3", visit.sheets.first
    assert_equal "sheet-#{Songbook::MAX_SONGS + 2}", visit.sheets.last
  end

  test "offers the set once the visit holds a second sheet" do
    visit = build_visit

    visit.record_sheet("first")
    assert_not visit.offer_pending?

    visit.record_sheet("second")
    assert visit.offer_pending?
  end

  test "one answer settles the offer for the rest of the visit" do
    visit = build_visit
    visit.record_sheet("first")
    visit.record_sheet("second")

    visit.answer_offer!

    assert visit.offer_answered?
    assert_not visit.offer_pending?

    # A sheet made after the answer does not ask the same visit again.
    visit.record_sheet("third")
    assert_not visit.offer_pending?
  end

  test "a list older than the visit reads as empty and is not answered" do
    clock = Clock.new(Time.utc(2026, 10, 7, 12, 0, 0))
    session = {}
    visit = Visit.new(session, clock: clock)
    visit.record_sheet("first")
    visit.record_sheet("second")
    visit.answer_offer!

    clock.now += (Visit::WINDOW_SECONDS + 1).seconds
    lapsed = Visit.new(session, clock: clock)

    assert_equal [], lapsed.sheets
    assert_equal 0, lapsed.sheet_count
    assert_not lapsed.offer_answered?
    assert_not lapsed.offer_pending?
  end

  test "a visit that lapsed starts over and can be offered again" do
    clock = Clock.new(Time.utc(2026, 10, 7, 12, 0, 0))
    session = {}
    visit = Visit.new(session, clock: clock)
    visit.record_sheet("first")
    visit.record_sheet("second")
    visit.answer_offer!

    clock.now += (Visit::WINDOW_SECONDS + 1).seconds
    later = Visit.new(session, clock: clock)
    later.record_sheet("third")

    assert_equal %w[third], later.sheets
    assert_not later.offer_answered?
  end

  test "the window is extended by the sheets a visit keeps making" do
    clock = Clock.new(Time.utc(2026, 10, 7, 12, 0, 0))
    session = {}
    visit = Visit.new(session, clock: clock)
    visit.record_sheet("first")

    clock.now += (Visit::WINDOW_SECONDS - 60).seconds
    visit.record_sheet("second")

    clock.now += (Visit::WINDOW_SECONDS - 60).seconds
    assert_equal %w[first second], visit.sheets
  end

  test "identifies each rendered offer on its own" do
    assert_not_equal build_visit.offer_key, build_visit.offer_key
  end

  test "reads a session holding something else as an empty visit" do
    visit = Visit.new({ visit: "nonsense" })

    assert_equal [], visit.sheets
    assert_not visit.offer_pending?
  end

  private

  def build_visit(session: {})
    Visit.new(session, clock: -> { Time.utc(2026, 10, 7, 12, 0, 0) })
  end
end
