# Allowlisted campaign query values. The frontend reads these from a data
# attribute so unknown query-string values can never become analytics
# properties. `docs/organic-search-operations.md` documents them for operators.
class AnalyticsCampaigns
  SOURCES = %w[church email facebook musician outreach reddit teacher].freeze
  CAMPAIGNS = %w[large_print singer_rehearsal teacher_handouts worship_handouts].freeze

  def self.to_h
    { sources: SOURCES, campaigns: CAMPAIGNS }
  end

  def self.to_json
    to_h.to_json
  end
end
