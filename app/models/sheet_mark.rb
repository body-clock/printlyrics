# frozen_string_literal: true

# The mark a printed sheet carries: a QR code that opens the sheet it was
# printed from, so a page passed around a rehearsal room has a way back. The
# address it encodes carries the campaign value `AnalyticsCampaigns` holds,
# because a scan arrives with no referrer and a saved page reports its location
# with the query string dropped, so that value is the only thing that can say
# the visitor came off paper.
#
# The code is drawn as one path over the modules the encoder produced, in module
# units, and scaled by CSS, so the same markup prints at any size. Nothing the
# visitor typed reaches this markup: the address is carried in the modules
# rather than written into the SVG.
class SheetMark
  # A scanner needs four clear modules around the code. Without the quiet zone a
  # code this small sits inside a page of text and will not lock on, so the
  # offset and the viewBox below both count it.
  QUIET_ZONE = 4

  # Medium correction survives the fold and the photocopier a printed sheet gets
  # exposed to, and this address is short enough that the size it costs stays
  # small: 37 modules, about 0.4 mm each at the printed size.
  CORRECTION_LEVEL = :m

  # Darker than the sheet's own near-black ink: a scanner wants the contrast
  # rather than the paper's quieter grey.
  MODULE_COLOR = "000"

  def initialize(url)
    @url = url
  end

  # The dark modules as a single SVG path, in module units, with no background
  # of its own so the paper behind it shows through.
  def path
    @path ||= code.as_svg(
      use_path: true,
      module_size: 1,
      offset: QUIET_ZONE,
      color: MODULE_COLOR,
      standalone: false
    )
  end

  # The mark's width and height in module units, quiet zone included. The
  # viewBox has to be this rather than the code's own count, or the quiet zone
  # is cropped away and the code stops scanning.
  def extent
    @extent ||= code.modules.length + (QUIET_ZONE * 2)
  end

  private

  def code
    @code ||= RQRCode::QRCode.new(@url, level: CORRECTION_LEVEL)
  end
end
