class SongSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :query, :string

  validates :query, presence: true
  validates :query, length: { maximum: 200 }

  attr_reader :results

  # Raises LrcLibClient::ServiceError when the source is unavailable. Callers
  # translate that into user copy and an HTTP status.
  def perform(client:)
    return false unless valid?

    @results = client.search(query)
    true
  end

  def empty?
    results&.empty?
  end
end
