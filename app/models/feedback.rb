# A visitor's own words, from the search-miss prompt on the entry panel or the
# feedback page. This table is the record: a song query, a note, and an opt-in
# address, with no lyric, title, or saved-page token among them.
#
# A stored submission is also reported to this site's own analytics service as
# `Feedback Submitted`, carrying the query, the note, and the surface, so the
# demand it holds can be read beside the counts around it
# (app/services/umami_client.rb). That report is Umami's alone; the reply
# address is not part of it, and docs/measurement-contract.md owns the rule.
class Feedback < ApplicationRecord
  # Where the form was shown. The value is allowlisted rather than free-form so
  # a submission can only be labelled with a surface this application renders.
  SURFACES = %w[search_miss feedback_page].freeze

  MAX_MESSAGE_LENGTH = 2000
  MAX_QUERY_LENGTH = 200

  validates :surface, inclusion: { in: SURFACES }
  validates :message, length: { maximum: MAX_MESSAGE_LENGTH }
  validates :query, length: { maximum: MAX_QUERY_LENGTH }
  validates :contact_email, length: { maximum: 200 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :something_to_read

  scope :recent, -> { order(created_at: :desc) }

  private

  # Either half is enough: the search-miss prompt asks for a song title and
  # leaves the note optional, while the feedback page asks for the note.
  def something_to_read
    return if message.present? || query.present?

    errors.add(:base, I18n.t("feedbacks.errors.blank"))
  end
end
