require "test_helper"

class AccountsFlowTest < ActionDispatch::IntegrationTest
  test "public lyric entry still works without an account" do
    get root_path

    assert_response :success
    assert_select "h1", "Find, format, and print song lyrics"
  end

  test "a free visitor can create one songbook per calendar day" do
    first = Lyric.create!(lyrics: "First line")
    second = Lyric.create!(lyrics: "Second line")

    post songbooks_path, params: { lyric_token: first.token }
    assert_response :redirect
    assert_equal 1, Songbook.count

    post songbooks_path, params: { lyric_token: second.token }
    assert_redirected_to save_songbooks_path
    assert_equal 1, Songbook.count

    travel 1.day do
      post songbooks_path, params: { lyric_token: second.token }
      assert_equal 2, Songbook.count
    end
  end

  test "a free account owns its songbook and cannot create a second on the same day" do
    user = User.create!(email_address: "writer@example.test", password: "long-password", password_confirmation: "long-password")
    first = Lyric.create!(lyrics: "First line")
    second = Lyric.create!(lyrics: "Second line")
    sign_in(user)

    post songbooks_path, params: { lyric_token: first.token }
    songbook = Songbook.order(:id).last
    assert_equal user, songbook.user
    assert songbook.expires_at.present?

    post songbooks_path, params: { lyric_token: second.token }
    assert_redirected_to save_songbooks_path
    assert_equal 1, user.songbooks.where(created_at: Time.current.all_day).count
  end

  test "registration claims the guest songbooks made in the same browser" do
    lyric = Lyric.create!(lyrics: "My song")
    post songbooks_path, params: { lyric_token: lyric.token }
    guest_songbook = Songbook.last

    post registrations_path, params: {
      user: {
        email_address: "new-owner@example.test",
        password: "long-password",
        password_confirmation: "long-password"
      }
    }

    assert_redirected_to root_path
    assert_equal User.find_by!(email_address: "new-owner@example.test"), guest_songbook.reload.user

    follow_redirect!
    assert_select "[data-analytics-page-response='Account Created']", 1
    get account_songbooks_path
    assert_response :success
    assert_select "a[href='#{songbook_path(guest_songbook)}']"
    assert_select "[data-analytics-page-response='Account Library Opened']", 1
  end

  test "account-owned songbooks require sign-in and appear in the owner's library" do
    user = User.create!(email_address: "owner@example.test", password: "long-password", password_confirmation: "long-password")
    songbook = Songbook.start_with(Lyric.create!(lyrics: "Saved words"), user: user)

    get songbook_path(songbook)
    assert_redirected_to new_session_path

    sign_in(user)
    get songbook_path(songbook)
    assert_response :success

    get account_songbooks_path
    assert_response :success
    assert_select "a[href='#{songbook_path(songbook)}']"

    sign_out
    get songbook_path(songbook)
    assert_redirected_to new_session_path
  end

  test "the library states the access the account holds" do
    free = User.create!(email_address: "library-free@example.test", password: "long-password", password_confirmation: "long-password")

    sign_in(free)
    get account_songbooks_path
    assert_response :success
    assert_select "p", /Free access: one songbook per calendar day/

    sign_out
    premium = User.create!(
      email_address: "library-premium@example.test",
      password: "long-password",
      password_confirmation: "long-password",
      premium_until: 3.days.from_now
    )

    sign_in(premium)
    get account_songbooks_path
    assert_response :success
    # The expiry is the part a paying visitor comes back to check, so the state
    # cannot be left to whichever controls the account's entitlement enables.
    assert_select "p", /Premium access is active until/
  end

  test "premium songbooks and their lyrics do not expire" do
    user = User.create!(
      email_address: "premium@example.test",
      password: "long-password",
      password_confirmation: "long-password",
      premium_until: 24.hours.from_now
    )
    lyric = Lyric.create!(lyrics: "Saved words")

    songbook = Songbook.start_with(lyric, user: user)

    assert_nil songbook.reload.expires_at
    assert_nil lyric.reload.expires_at
  end

  test "premium share links are read-only, measurable, and revocable" do
    user = User.create!(
      email_address: "sharing@example.test",
      password: "long-password",
      password_confirmation: "long-password",
      premium_until: 24.hours.from_now
    )
    songbook = Songbook.start_with(Lyric.create!(lyrics: "Shared words"), user: user)
    sign_in(user)

    post share_songbook_path(songbook)
    assert_redirected_to songbook_path(songbook)
    songbook.reload
    assert songbook.share_token.present?
    follow_redirect!
    assert_select "[data-analytics-page-response='Songbook Share Link Created']", 1
    assert_select ".songbook-sharing a[href='#{shared_songbook_url(songbook.share_token)}']"

    get shared_songbook_path(songbook.share_token)
    assert_response :success
    assert_select "meta[name='robots'][content='noindex, nofollow']", 1
    assert_select "[data-analytics-page-response='Shared Songbook Opened']", 1
    assert_select ".songbook-track-remove", count: 0
    assert_select ".songbook-sharing", count: 0
    assert_select ".button-print", count: 1

    delete revoke_songbook_share_path(songbook)
    assert_redirected_to songbook_path(songbook)
    assert_nil songbook.reload.share_token
    follow_redirect!
    assert_select "[data-analytics-page-response='Songbook Share Link Revoked']", 1

    get shared_songbook_path("revoked-token")
    assert_redirected_to root_path
  end

  test "free account cannot create premium share links" do
    user = User.create!(email_address: "free-sharing@example.test", password: "long-password", password_confirmation: "long-password")
    songbook = Songbook.start_with(Lyric.create!(lyrics: "Private words"), user: user)
    sign_in(user)

    post share_songbook_path(songbook)

    assert_redirected_to save_songbooks_path
    assert_nil songbook.reload.share_token
  end

  test "activating premium preserves existing active account songbooks" do
    user = User.create!(email_address: "upgrade@example.test", password: "long-password", password_confirmation: "long-password")
    lyric = Lyric.create!(lyrics: "Existing words")
    songbook = Songbook.start_with(lyric, user: user)

    user.activate_premium_until!(24.hours.from_now)

    assert_nil songbook.reload.expires_at
    assert_nil lyric.reload.expires_at
    assert user.premium?
  end

  private

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "long-password" }
    follow_redirect! if response.redirect?
  end

  def sign_out
    delete session_path
    follow_redirect! if response.redirect?
  end
end
