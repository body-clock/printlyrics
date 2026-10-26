require "test_helper"

class SongbooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @first = Lyric.create!(lyrics: "First line", title: "First")
    @second = Lyric.create!(lyrics: "Second line", title: "Second")
    @songbook = Songbook.start_with(@first, @second)
  end

  test "updating one song keeps that song's own layout" do
    patch update_songbook_song_path(@songbook, @first.token),
      params: { size: "xl", columns: 2 },
      as: :json

    assert_response :no_content
    assert_equal [ "xl", 2 ], layout_of(@first)
    assert_equal [ "m", 1 ], layout_of(@second)
  end

  test "a one-dimension song patch preserves its other dimension and neighbouring songs" do
    @songbook.entries.find_by!(lyric: @first).update!(columns: 2)

    patch update_songbook_song_path(@songbook, @first.token), params: { size: "l" }, as: :json

    assert_response :no_content
    assert_equal [ "l", 2 ], layout_of(@first)
    assert_equal [ "m", 1 ], layout_of(@second)

    patch update_songbook_song_path(@songbook, @first.token), params: { columns: 1 }, as: :json

    assert_response :no_content
    assert_equal [ "l", 1 ], layout_of(@first)
  end

  test "updating the songbook applies one layout to every song" do
    patch songbook_path(@songbook), params: { size: "l", columns: 1 }, as: :json

    assert_response :no_content
    assert_equal [ [ "l", 1 ], [ "l", 1 ] ],
      @songbook.entries.reload.map { |entry| [ entry.size, entry.columns ] }
  end

  test "bulk size keeps a mixed column choice" do
    @songbook.entries.find_by!(lyric: @first).update!(columns: 2)

    patch songbook_path(@songbook), params: { size: "s" }, as: :json

    assert_response :no_content
    assert_equal [ [ "s", 2 ], [ "s", 1 ] ],
      @songbook.entries.reload.map { |entry| [ entry.size, entry.columns ] }
  end

  test "bulk columns keep a mixed size choice" do
    @songbook.entries.find_by!(lyric: @first).update!(size: "xl")

    patch songbook_path(@songbook), params: { columns: 2 }, as: :json

    assert_response :no_content
    assert_equal [ [ "xl", 2 ], [ "m", 2 ] ],
      @songbook.entries.reload.map { |entry| [ entry.size, entry.columns ] }
  end

  test "rejects an unsupported layout without changing the entry" do
    patch update_songbook_song_path(@songbook, @first.token),
      params: { size: "huge", columns: 9 },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "m", 1 ], layout_of(@first)
  end

  test "creating a songbook carries the sheet's current layout" do
    lyric = Lyric.create!(lyrics: "Fresh line", title: "Fresh")

    post songbooks_path, params: { lyric_token: lyric.token, size: "xl", columns: 2 }

    created = Songbook.order(:id).last
    assert_redirected_to songbook_path(created)
    assert_equal [ [ "xl", 2 ] ],
      created.entries.map { |entry| [ entry.size, entry.columns ] }
  end

  test "creating a songbook falls back to the default layout when the request is invalid" do
    lyric = Lyric.create!(lyrics: "Fresh line", title: "Fresh")

    post songbooks_path, params: { lyric_token: lyric.token, size: "huge", columns: 9 }

    created = Songbook.order(:id).last
    assert_equal [ [ "m", 1 ] ],
      created.entries.map { |entry| [ entry.size, entry.columns ] }
  end

  test "rejects a layout request for an expired songbook" do
    @songbook.update_column(:expires_at, 1.minute.ago)

    patch update_songbook_song_path(@songbook, @first.token),
      params: { size: "l", columns: 2 },
      as: :json

    assert_response :not_found
    assert_equal [ "m", 1 ], layout_of(@first)
  end

  private

  def layout_of(lyric)
    entry = @songbook.entries.find_by!(lyric: lyric)
    [ entry.size, entry.columns ]
  end
end
