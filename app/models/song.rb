class Song < ApplicationRecord
  has_many :lyrics

  before_validation :set_slug, on: :create

  validates :source_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :slug, presence: true, uniqueness: true, length: { maximum: 450 }
  validates :title, :artist, presence: true, length: { maximum: 200 }
  validates :album, length: { maximum: 300 }, allow_blank: true
  validates :duration_seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :print_page_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :indexable, -> { where.not(indexable_at: nil).where(unavailable_at: nil) }

  def indexable?
    indexable_at.present? && unavailable_at.nil?
  end

  def to_param
    slug
  end

  def promote!(metadata, verified_at: Time.current)
    public_state = metadata.slice(:title, :artist, :album, :duration_seconds).merge(
      indexable_at: indexable_at || verified_at,
      unavailable_at: nil
    )
    counters = {
      last_verified_at: verified_at,
      print_page_count: print_page_count + 1
    }

    return update_columns(counters) unless attributes_changed?(public_state)

    update!(public_state.merge(counters))
  end

  def refresh_from_result!(result, verified_at: Time.current)
    metadata = {
      title: result.title,
      artist: result.artist,
      album: result.album.presence,
      duration_seconds: result.duration.round,
      unavailable_at: nil
    }

    return update_column(:last_verified_at, verified_at) unless attributes_changed?(metadata)

    update!(metadata.merge(last_verified_at: verified_at))
  end

  def mark_unavailable!(verified_at: Time.current)
    return update_column(:last_verified_at, verified_at) if unavailable_at?

    update!(unavailable_at: verified_at, last_verified_at: verified_at)
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
