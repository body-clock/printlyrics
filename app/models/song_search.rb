class SongSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :query, :string

  validates :query, presence: { message: "Enter a song title or artist" }
  validates :query, length: { maximum: 200, message: "Keep your search under 200 characters" }

  attr_reader :results

  def perform(client:)
    return false unless valid?

    @results = client.search(query)
    true
  rescue LrcLibClient::ServiceError
    @error = "Song search is temporarily unavailable. You can still paste lyrics below."
    @service_error = true
    false
  end

  def success?
    results&.any?
  end

  def error_message
    @error || (errors.full_messages.first unless valid?)
  end

  def http_status
    return :service_unavailable if @service_error
    return :unprocessable_content if error_message
    :ok
  end
end
