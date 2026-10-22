require "test_helper"

class UserTest < ActiveSupport::TestCase
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

  test "an email address is normalized before it is stored" do
    user = User.create!(
      email_address: "  Person@Example.TEST ",
      password: "long-password",
      password_confirmation: "long-password"
    )

    assert_equal "person@example.test", user.email_address
  end

  test "an account changes without restating its password" do
    user = create_user

    assert user.update(email_address: "elsewhere@example.test")
  end

  test "the library offers ten places across both kinds of saved page" do
    user = create_user

    9.times { SavedItem.add(user: user, item: Lyric.create!(lyrics: "A line")) }
    SavedItem.add(user: user, item: Songbook.start_with(Lyric.create!(lyrics: "A set")))

    assert user.library_full?
    assert_raises(SavedItem::LimitReached) do
      SavedItem.add(user: user, item: Lyric.create!(lyrics: "One more"))
    end
  end

  private

  def create_user
    User.create!(
      email_address: "keeper@example.test",
      password: "long-password",
      password_confirmation: "long-password"
    )
  end
end
