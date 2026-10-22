require "test_helper"

class SavedItemTest < ActiveSupport::TestCase
  test "saving a lyric keeps it and its page out of the retention clock" do
    user = create_user
    lyric = Lyric.create!(lyrics: "A line", expires_at: 1.day.from_now)

    saved_item = SavedItem.add(user: user, item: lyric)

    assert_equal user, saved_item.user
    assert_nil lyric.reload.expires_at
  end

  test "saving a songbook keeps every song in it" do
    user = create_user
    first = Lyric.create!(lyrics: "First")
    second = Lyric.create!(lyrics: "Second")
    songbook = Songbook.start_with(first, second)

    SavedItem.add(user: user, item: songbook)

    assert_nil songbook.reload.expires_at
    assert_nil first.reload.expires_at
    assert_nil second.reload.expires_at
  end

  test "a song added to a kept songbook is kept too" do
    user = create_user
    songbook = Songbook.start_with(Lyric.create!(lyrics: "First"))
    SavedItem.add(user: user, item: songbook)
    added = Lyric.create!(lyrics: "Second")

    songbook.append!(added)

    assert_nil added.reload.expires_at
  end

  test "the same page is saved once and does not consume a second place" do
    user = create_user
    lyric = Lyric.create!(lyrics: "A line")

    first = SavedItem.add(user: user, item: lyric)
    second = SavedItem.add(user: user, item: lyric)

    assert_equal first, second
    assert_equal 1, user.saved_items.count
  end

  test "only lyric sheets and songbooks can be saved" do
    assert_raises(ArgumentError) do
      SavedItem.add(user: create_user, item: Feedback.new)
    end
  end

  test "removing a lyric puts it back on the 180-day clock" do
    user = create_user
    lyric = Lyric.create!(lyrics: "A line")
    saved_item = SavedItem.add(user: user, item: lyric)

    saved_item.release!

    assert_not SavedItem.exists?(saved_item.id)
    assert_in_delta Retained::RETENTION_PERIOD.from_now, lyric.reload.expires_at, 1.minute
  end

  test "removing a lyric that a kept songbook holds does not expire it" do
    user = create_user
    lyric = Lyric.create!(lyrics: "A line")
    songbook = Songbook.start_with(lyric)
    SavedItem.add(user: user, item: songbook)
    saved_lyric = SavedItem.add(user: user, item: lyric)

    saved_lyric.release!

    assert_nil lyric.reload.expires_at
  end

  test "a page another account still keeps does not expire" do
    owner = create_user
    other = create_user(email_address: "other@example.test")
    lyric = Lyric.create!(lyrics: "Shared line")
    first = SavedItem.add(user: owner, item: lyric)
    SavedItem.add(user: other, item: lyric)

    first.release!

    assert_nil lyric.reload.expires_at
  end

  test "removing a song from a kept songbook returns it to the retention clock" do
    user = create_user
    first = Lyric.create!(lyrics: "First")
    second = Lyric.create!(lyrics: "Second")
    songbook = Songbook.start_with(first, second)
    SavedItem.add(user: user, item: songbook)

    songbook.remove!(first)

    assert_in_delta Retained::RETENTION_PERIOD.from_now, first.reload.expires_at, 1.minute
    assert_nil second.reload.expires_at
  end

  test "removing a song another kept songbook holds does not expire it" do
    user = create_user
    shared = Lyric.create!(lyrics: "Shared")
    kept = Songbook.start_with(shared, Lyric.create!(lyrics: "Kept"))
    removable = Songbook.start_with(shared, Lyric.create!(lyrics: "Removable"))
    SavedItem.add(user: user, item: kept)
    SavedItem.add(user: user, item: removable)

    removable.remove!(shared)

    assert_nil shared.reload.expires_at
  end

  test "removing a songbook expires its songs" do
    user = create_user
    first = Lyric.create!(lyrics: "First")
    second = Lyric.create!(lyrics: "Second")
    songbook = Songbook.start_with(first, second)
    saved_item = SavedItem.add(user: user, item: songbook)

    saved_item.release!

    assert_in_delta Retained::RETENTION_PERIOD.from_now, songbook.reload.expires_at, 1.minute
    assert_in_delta Retained::RETENTION_PERIOD.from_now, first.reload.expires_at, 1.minute
    assert_in_delta Retained::RETENTION_PERIOD.from_now, second.reload.expires_at, 1.minute
  end

  private

  def create_user(email_address: "keeper@example.test")
    User.create!(
      email_address: email_address,
      password: "long-password",
      password_confirmation: "long-password"
    )
  end
end
