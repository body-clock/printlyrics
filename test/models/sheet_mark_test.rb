require "test_helper"

class SheetMarkTest < ActiveSupport::TestCase
  ADDRESS = "https://printlyrics.app/lyrics/aBcDeFgHiJkLmNoP?utm_source=paper"

  test "leaves the spec quiet zone around the code" do
    mark = SheetMark.new(ADDRESS)
    module_count = RQRCode::QRCode.new(ADDRESS, level: SheetMark::CORRECTION_LEVEL).modules.length

    # The viewBox is built from the extent, so a mark that counted its own
    # modules alone would crop the quiet zone and stop scanning; the offset is
    # the same quiet zone in the path the module grid is drawn from.
    assert_equal module_count + (SheetMark::QUIET_ZONE * 2), mark.extent
    assert_includes mark.path, "translate(#{SheetMark::QUIET_ZONE},#{SheetMark::QUIET_ZONE})"
  end

  test "draws the address it was given" do
    mark = SheetMark.new(ADDRESS)

    # A printed sheet is held for longer than this process lives, so the same
    # address has to draw the same code every time, and two sheets have to draw
    # two different ones.
    assert_equal mark.path, SheetMark.new(ADDRESS).path
    refute_equal mark.path, SheetMark.new(ADDRESS.sub("aBcDeFgHiJkLmNoP", "zYxWvUtSrQpOnMlK")).path
  end
end
