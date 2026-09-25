# A visitor's own words, from the search-miss prompt on the entry panel or the
# feedback page. This table and the operator's terminal are the only places a
# submission appears: a song query, a note, and an opt-in address are never sent
# to analytics, and no lyric, title, or saved-page token travels with them.
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
