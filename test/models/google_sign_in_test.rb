require "test_helper"

class GoogleSignInTest < ActiveSupport::TestCase
  def google_auth(uid: "google-uid-1", email: "person@example.test", email_verified: true,
    provider: "google_oauth2")
    OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid,
      info: {
        name: "Google Person",
        email: email_verified ? email : nil,
        unverified_email: email,
        email_verified: email_verified
      }
    )
  end

  def sign_in(**options) = GoogleSignIn.new(google_auth(**options))

  test "a verified address with no account creates one and links it" do
    with_google_configured do
      sign_in_with_google = sign_in

      user = sign_in_with_google.call

      assert sign_in_with_google.created?
      assert_equal "person@example.test", user.email_address
      assert_equal [ [ "google_oauth2", "google-uid-1" ] ],
        user.identities.map { |identity| [ identity.provider, identity.uid ] }
      assert_not user.authenticate("anything")
    end
  end

  test "an existing password account is not claimed by a Google sign-in" do
    with_google_configured do
      existing = User.create!(
        email_address: "person@example.test",
        password: "long-password",
        password_confirmation: "long-password"
      )

      assert_raises(GoogleSignIn::Refused) { sign_in.call }
      assert_equal 1, User.count
      assert_equal 0, existing.identities.count
      assert existing.reload.authenticate("long-password")
    end
  end

  test "a second sign-in is found by the identity the first one wrote" do
    with_google_configured do
      first = sign_in(email: "person@example.test").call
      returning = sign_in(email: "person@example.test")

      assert_equal first, returning.call
      assert_not returning.created?
      assert_equal 1, User.count
      assert_equal 1, Identity.count
    end
  end

  test "a returning visitor is found by the uid even when the address changed" do
    with_google_configured do
      first = sign_in(email: "before@example.test").call

      returning = sign_in(uid: "google-uid-1", email: "after@example.test")

      assert_equal first, returning.call
      assert_not returning.created?
      assert_equal [ "before@example.test" ], User.pluck(:email_address)
      assert_equal 1, Identity.count
    end
  end

  test "an unverified address is refused and writes nothing" do
    with_google_configured do
      assert_raises(GoogleSignIn::Refused) { sign_in(email_verified: false).call }
      assert_equal 0, User.count
      assert_equal 0, Identity.count
    end
  end

  test "a verified payload with no address is refused" do
    with_google_configured do
      auth = google_auth
      auth.info.email = nil

      assert_raises(GoogleSignIn::Refused) { GoogleSignIn.new(auth).call }
      assert_equal 0, Identity.count
    end
  end

  test "another provider and a missing payload are refused" do
    with_google_configured do
      assert_raises(GoogleSignIn::Refused) { sign_in(provider: "github").call }
      assert_raises(GoogleSignIn::Refused) { sign_in(uid: "").call }
      assert_raises(GoogleSignIn::Refused) { GoogleSignIn.new(nil).call }
      assert_equal 0, User.count
    end
  end

  test "a host that cannot sign anyone in with Google refuses every payload" do
    assert_not GoogleSignIn.configured?

    assert_raises(GoogleSignIn::Refused) { sign_in.call }
    assert_equal 0, User.count
  end
end
