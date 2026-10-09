# A visitor's own words, from the search-miss prompt on the entry panel, the
# sheet that was just generated, or the feedback page. This table is the record:
# a song query, a note, an opt-in address, and the one answer offered as a
# select, with no lyric, title, or saved-page token among them.
#
# A stored submission is also reported to this site's own analytics service as
# `Feedback Submitted`, carrying the query, the note, the surface, and the
# answer, so the demand it holds can be read beside the counts around it
# (app/services/umami_client.rb). That report is Umami's alone; the reply
# address is not part of it, and docs/measurement-contract.md owns the rule.
class Feedback < ApplicationRecord
  # Where the form was shown. The value is allowlisted rather than free-form so
  # a submission can only be labelled with a surface this application renders.
  SURFACES = %w[search_miss sheet feedback_page].freeze

  # The one question every surface asks the same way — what is this about? A
  # fixed vocabulary keeps the answer countable, and the sheet prompt's link
  # carries its answer, so that surface asks nothing of the visitor.
  REASONS = %w[missing_song print_problem wrong_lyrics idea].freeze

  MAX_MESSAGE_LENGTH = 2000
  MAX_QUERY_LENGTH = 200

  validates :surface, inclusion: { in: SURFACES }
  validates :message, length: { maximum: MAX_MESSAGE_LENGTH }
  validates :query, length: { maximum: MAX_QUERY_LENGTH }
  validates :contact_email, length: { maximum: 200 },
    format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :something_to_read

  # The answer labels a submission for reading rather than granting anything, so
  # a value this application never offered is dropped instead of refusing the
  # words the visitor wrote.
  before_validation :keep_offered_reason

  scope :recent, -> { order(created_at: :desc) }

  private

  def keep_offered_reason
    self.reason = REASONS.include?(reason) ? reason : nil
  end

  # Either half is enough: the search-miss prompt asks for a song title and
  # leaves the note optional, while the feedback page asks for the note.
  def something_to_read
    return if message.present? || query.present?

    errors.add(:base, I18n.t("feedbacks.errors.blank"))
  end
end
