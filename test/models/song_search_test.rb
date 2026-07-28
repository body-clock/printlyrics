require "test_helper"

class SongSearchTest < ActiveSupport::TestCase
  test "blank query uses the localized validation message" do
    search = SongSearch.new(query: "")

    assert_not search.valid?
    assert_equal I18n.t("activemodel.errors.models.song_search.attributes.query.blank"),
      search.errors.first.message
  end

  test "long query uses the localized validation message" do
    search = SongSearch.new(query: "a" * 201)

    assert_not search.valid?
    assert_equal I18n.t("activemodel.errors.models.song_search.attributes.query.too_long"),
      search.errors.first.message
  end

  test "service failure uses the shared localized error" do
    client = Object.new
    client.define_singleton_method(:search) { |_| raise LrcLibClient::ServiceError }
    search = SongSearch.new(query: "a song")

    assert_not search.perform(client: client)
    assert_equal I18n.t("songs.errors.service"), search.error_message
  end
end
