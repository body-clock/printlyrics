require "test_helper"

class UserTest < ActiveSupport::TestCase
  # has_secure_password enforces bcrypt's 72-byte ceiling and no floor, so the
  # account that guards a saved library and a paid entitlement carries its own.
  test "a password below the minimum is refused" do
    short = "a" * (User::PASSWORD_MINIMUM_LENGTH - 1)
    user = User.new(
      email_address: "short@example.test",
      password: short,
      password_confirmation: short
    )

    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_short)

    exact = "a" * User::PASSWORD_MINIMUM_LENGTH
    user.password = user.password_confirmation = exact

    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "an account changes without restating its password" do
    user = User.create!(
      email_address: "keeper@example.test",
      password: "long-password",
      password_confirmation: "long-password"
    )

    assert user.update(email_address: "elsewhere@example.test")
  end

  # What a free account keeps for reprinting, and what premium removes the ceiling
  # from. A place comes free again when the book holding it lapses.
  test "a free account holds five songbooks and no more" do
    user = create_user

    (User::FREE_SONGBOOK_LIMIT - 1).times { Songbook.start_with(Lyric.create!(lyrics: "A line"), user: user) }
    assert user.can_create_songbook?

    Songbook.start_with(Lyric.create!(lyrics: "One more"), user: user)
    assert_not user.can_create_songbook?
    assert_equal User::FREE_SONGBOOK_LIMIT, user.songbooks.active.count

    assert_raises(Songbook::StorageLimitReached) do
      Songbook.start_with(Lyric.create!(lyrics: "Too many"), user: user)
    end
    assert_equal User::FREE_SONGBOOK_LIMIT, user.songbooks.active.count
  end

  test "a lapsed songbook frees the place it held" do
    user = create_user
    books = User::FREE_SONGBOOK_LIMIT.times.map do
      Songbook.start_with(Lyric.create!(lyrics: "A line"), user: user)
    end
    assert_not user.can_create_songbook?

    books.first.update!(expires_at: 1.minute.ago)

    assert user.can_create_songbook?
  end

  test "premium access leaves the account with no ceiling" do
    user = create_user(premium_until: 24.hours.from_now)

    (User::FREE_SONGBOOK_LIMIT + 1).times { Songbook.start_with(Lyric.create!(lyrics: "A line"), user: user) }

    assert user.can_create_songbook?
    assert_equal User::FREE_SONGBOOK_LIMIT + 1, user.songbooks.active.count
  end

  private

  def create_user(**attributes)
    @user_count = (@user_count || 0) + 1
    User.create!(
      email_address: "keeper#{@user_count}@example.test",
      password: "long-password",
      password_confirmation: "long-password",
      **attributes
    )
  end
end
