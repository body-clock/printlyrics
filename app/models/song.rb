class Song < ApplicationRecord
  has_many :lyrics

  before_validation :set_slug, on: :create

  validates :source_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 450 }
  validates :title, :artist, presence: true, length: { maximum: 200 }
  validates :album, length: { maximum: 300 }, allow_blank: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :print_page_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def to_param
    slug
  end

  # One row per sourced LRCLIB record, so repeated prints reuse a single
  # metadata row and accumulate a demand count. Nothing here is published: the
  # public song catalog was removed after it earned impressions but no clicks.
  def promote!(metadata, verified_at: Time.current)
    next_print_page_count = print_page_count + 1
    source_state = metadata.slice(:title, :artist, :album, :duration_seconds)
    counters = {
      last_verified_at: verified_at,
      print_page_count: next_print_page_count
    }

    return update_columns(counters) unless attributes_changed?(source_state)

    update!(source_state.merge(counters))
  end

  private

  def attributes_changed?(attributes)
    attributes.any? { |attribute, value| public_send(attribute) != value }
  end

  def set_slug
    return if slug.present? || source_id.blank?

    prefix = [ artist, title ].filter_map(&:presence).join(" ").parameterize
    self.slug = [ prefix.presence || "song", source_id ].join("-")
  end
end
