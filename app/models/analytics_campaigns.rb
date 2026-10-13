# Allowlisted campaign query values. The frontend reads these from a data
# attribute so unknown query-string values can never become analytics
# properties. `docs/organic-search-operations.md` documents them for operators.
class AnalyticsCampaigns
  # What the printed sheet's code carries. A scan reaches a saved page with no
  # referrer, and a saved page drops the query string from the location it
  # reports, so this value reaches the dashboard as the allowlisted property
  # rather than through the landing URL's native attribution.
  SHEET_SOURCE = "paper"

  SOURCES = (%w[church email facebook musician outreach reddit teacher] << SHEET_SOURCE).freeze
  CAMPAIGNS = %w[large_print singer_rehearsal teacher_handouts worship_handouts].freeze

  def self.to_h
    { sources: SOURCES, campaigns: CAMPAIGNS }
  end

  def self.to_json
    to_h.to_json
  end
end
