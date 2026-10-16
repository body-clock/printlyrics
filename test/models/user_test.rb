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
end
