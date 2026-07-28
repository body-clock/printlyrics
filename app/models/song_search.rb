class SongSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :query, :string

  validates :query, presence: true
  validates :query, length: { maximum: 200 }

  attr_reader :results

  def perform(client:)
    return false unless valid?

    @results = client.search(query)
    true
  rescue LrcLibClient::ServiceError
    @error = I18n.t("songs.errors.service")
    @service_error = true
    false
  end

  def success?
    results&.any?
  end

  def error_message
    @error || (errors.first&.message unless valid?)
  end

  def http_status
    return :service_unavailable if @service_error
    return :unprocessable_content if error_message
    :ok
  end
end
