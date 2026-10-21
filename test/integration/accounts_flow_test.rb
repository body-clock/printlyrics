require "test_helper"

class AccountsFlowTest < ActionDispatch::IntegrationTest
  test "the public tool still works without an account" do
    get root_path

    assert_response :success
    assert_select "h1", "Find, format, and print song lyrics"
    assert_select ".site-header a[href='#{new_session_path}']"
    assert_select ".site-header a[href='#{new_registration_path}']"
  end

  test "registration creates an account, starts a session, and opens the library" do
    assert_difference("User.count", 1) do
      post registrations_path, params: {
        user: {
          email_address: " NewOwner@Example.TEST ",
          password: "long-password",
          password_confirmation: "long-password"
        }
      }
    end

    assert_redirected_to root_url
    user = User.find_by!(email_address: "newowner@example.test")
    assert_equal 1, user.sessions.count

    follow_redirect!
    assert_select "[role=status]", /Account created/
    assert_select "[data-analytics-page-response='Account Created']", 1
    created = css_select("[data-analytics-page-response='Account Created']").first
    assert_equal "password", JSON.parse(created["data-analytics-props"])["account_method"]

    get library_path
    assert_response :success
    assert_select "h1", "Your library"
    assert_select ".library-count", "0 of 10 saved"
    assert_select ".library-meter span", count: 10
    assert_select ".library-meter span.is-filled", count: 0
    assert_select ".site-account-email", user.email_address
    assert_select "[data-analytics-page-response='Account Library Opened']", 1
  end

  test "a short password is refused and the form keeps the email" do
    assert_no_difference("User.count") do
      post registrations_path, params: {
        user: {
          email_address: "short@example.test",
          password: "short",
          password_confirmation: "short"
        }
      }
    end

    assert_response :unprocessable_content
    assert_select ".form-errors", /too short/i
    assert_select "input[name='user[email_address]'][value='short@example.test']"
  end

  test "email sign-in ignores case and spaces, and a wrong password does not sign in" do
    user = create_user

    post session_path, params: { email_address: " WRITER@EXAMPLE.TEST ", password: "long-password" }
    assert_redirected_to root_url
    follow_redirect!
    assert_select "[data-analytics-page-response='Account Signed In']", 1
    signed_in = css_select("[data-analytics-page-response='Account Signed In']").first
    assert_equal "password", JSON.parse(signed_in["data-analytics-props"])["account_method"]

    get library_path
    assert_response :success

    delete session_path
    assert_redirected_to root_path

    get library_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: user.email_address, password: "wrong-password" }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /didn't match/
  end

  test "a reset link sets a new password and invalidates the old sessions" do
    user = create_user
    sign_in(user)
    assert_equal 1, user.sessions.count

    assert_enqueued_email_with PasswordsMailer, :reset, args: [ user ] do
      post passwords_path, params: { email_address: user.email_address }
    end
    assert_redirected_to new_session_path

    token = user.password_reset_token
    get edit_password_path(token)
    assert_response :success

    patch password_path(token), params: {
      password: "another-password",
      password_confirmation: "another-password"
    }
    assert_redirected_to new_session_path
    assert_equal 0, user.sessions.count

    post session_path, params: { email_address: user.email_address, password: "another-password" }
    assert_redirected_to root_url
  end

  test "a saved lyric is kept, appears in the library, and can be removed" do
    user = create_user
    sign_in(user)
    lyric = Lyric.create!(lyrics: "A line to print", title: "Saved Song")

    post saved_items_path, params: { item_type: "Lyric", token: lyric.token }

    assert_redirected_to lyric_path(lyric)
    assert_nil lyric.reload.expires_at
    assert user.saved?(lyric)
    follow_redirect!
    assert_select "[data-analytics-page-response='Library Item Saved']", 1
    saved = css_select("[data-analytics-page-response='Library Item Saved']").first
    assert_equal "lyric", JSON.parse(saved["data-analytics-props"])["saved_item_type"]
    assert_equal "library", JSON.parse(saved["data-analytics-props"])["save_source"]

    get library_path
    assert_response :success
    assert_select ".library-count", "1 of 10 saved"
    assert_select ".library-meter span.is-filled", count: 1
    assert_select ".library-card .library-kind", "Lyric sheet"
    assert_select ".library-card h2 a[href='#{lyric_path(lyric)}']", /Saved Song/

    saved_item = user.saved_items.sole
    delete saved_item_path(saved_item)

    assert_redirected_to library_path
    assert_not SavedItem.exists?(saved_item.id)
    assert_in_delta Retained::RETENTION_PERIOD.from_now, lyric.reload.expires_at, 1.minute
  end

  test "a saved songbook keeps its songs and the library names it by them" do
    user = create_user
    sign_in(user)
    first = Lyric.create!(lyrics: "First line", title: "First Song")
    second = Lyric.create!(lyrics: "Second line", title: "Second Song")
    songbook = Songbook.start_with(first, second)

    post saved_items_path, params: { item_type: "Songbook", token: songbook.token }

    assert_redirected_to songbook_path(songbook)
    assert_nil songbook.reload.expires_at
    assert_nil first.reload.expires_at
    assert_nil second.reload.expires_at

    get library_path
    assert_select ".library-card .library-kind", "Songbook"
    assert_select ".library-card h2 a[href='#{songbook_path(songbook)}']", /First Song · 2 songs/
  end

  test "the library holds ten items across lyric sheets and songbooks" do
    user = create_user
    sign_in(user)

    9.times do |index|
      lyric = Lyric.create!(lyrics: "Line #{index}", title: "Song #{index}")
      post saved_items_path, params: { item_type: "Lyric", token: lyric.token }
    end
    songbook = Songbook.start_with(Lyric.create!(lyrics: "Set line", title: "Set Song"))
    post saved_items_path, params: { item_type: "Songbook", token: songbook.token }

    assert_equal SavedItem::LIMIT, user.saved_items.count

    eleventh = Lyric.create!(lyrics: "One more", title: "One More")
    post saved_items_path, params: { item_type: "Lyric", token: eleventh.token }

    assert_redirected_to library_path
    assert_equal SavedItem::LIMIT, user.saved_items.count
    assert_not_nil eleventh.reload.expires_at
    follow_redirect!
    assert_select "[role=alert]", /used all 10 spots/
  end

  test "saving while signed out finishes after registration and returns to the page" do
    lyric = Lyric.create!(lyrics: "A line", title: "Keep Me")

    post saved_items_path, params: { item_type: "Lyric", token: lyric.token }

    assert_redirected_to new_session_path
    assert_equal "Lyric", session[:pending_save]["item_type"]
    assert_equal lyric.token, session[:pending_save]["token"]

    post registrations_path, params: {
      user: {
        email_address: "saver@example.test",
        password: "long-password",
        password_confirmation: "long-password"
      }
    }

    assert_redirected_to lyric_path(lyric)
    assert User.find_by!(email_address: "saver@example.test").saved?(lyric)
    assert_nil lyric.reload.expires_at
    follow_redirect!
    assert_select "[role=status]", /Saved\. You can open it here any time/
    assert_select ".library-prompt", /Saved in/
  end

  test "an expired page cannot be saved and an unknown item type is refused" do
    user = create_user
    sign_in(user)
    lyric = Lyric.create!(lyrics: "Gone", expires_at: 1.minute.ago)

    post saved_items_path, params: { item_type: "Lyric", token: lyric.token }
    assert_redirected_to root_path
    follow_redirect!
    assert_select "[role=alert]", /expired or can't be found/

    post saved_items_path, params: { item_type: "User", token: user.id }
    assert_redirected_to root_path
    assert_equal 0, user.saved_items.count
  end

  test "a generated sheet prompts once and not now settles it for the visit" do
    lyric = generate_sheet(title: "Prompt Sheet")

    assert_select ".account-prompt .account-prompt-title", /Save this sheet for later/
    shown = css_select("[data-analytics-page-response='Account Prompt Shown']").first
    assert_equal "sheet", JSON.parse(shown["data-analytics-props"])["account_prompt_surface"]

    delete account_prompt_path, params: { surface: "sheet" }

    assert_redirected_to root_path
    follow_redirect!
    assert_select "[data-analytics-page-response='Account Prompt Dismissed']", 1
    dismissed = css_select("[data-analytics-page-response='Account Prompt Dismissed']").first
    assert_equal "sheet", JSON.parse(dismissed["data-analytics-props"])["account_prompt_surface"]

    get lyric_path(lyric)
    assert_select ".account-prompt", count: 0
  end

  test "the second sheet leaves the ask to the songbook offer" do
    generate_sheet(title: "First Song")
    generate_sheet(title: "Second Song")

    assert_select ".songbook-prompt", count: 1
    assert_select ".account-prompt", count: 0

    delete songbook_offer_path
    follow_redirect!
    generate_sheet(title: "Third Song")

    assert_select ".account-prompt", count: 1
  end

  test "a sheet this visit did not make does not prompt" do
    lyric = Lyric.create!(lyrics: "Someone else's line", title: "Shared Sheet")

    get lyric_path(lyric)

    assert_response :success
    assert_select ".account-prompt", count: 0
    assert_select "[data-analytics-page-response='Account Prompt Shown']", count: 0
  end

  test "a signed-in visitor sees the library action instead of the account prompt" do
    user = create_user
    sign_in(user)

    generate_sheet(title: "Member Sheet")

    assert_select ".account-prompt", count: 0
    assert_select ".library-prompt", text: /Save to your library/
  end

  test "a songbook made by the visit prompts with its own surface" do
    first = generate_sheet(title: "First Song")
    second = generate_sheet(title: "Second Song")

    post songbooks_path, params: { lyric_tokens: [ first.token, second.token ] }

    assert_redirected_to songbook_path(Songbook.last)
    follow_redirect!
    assert_select ".account-prompt .account-prompt-title", /Save this songbook/
    shown = css_select("[data-analytics-page-response='Account Prompt Shown']").first
    assert_equal "songbook", JSON.parse(shown["data-analytics-props"])["account_prompt_surface"]
  end

  test "a shared songbook does not prompt" do
    songbook = Songbook.start_with(
      Lyric.create!(lyrics: "First line"),
      Lyric.create!(lyrics: "Second line")
    )

    get songbook_path(songbook)

    assert_response :success
    assert_select ".account-prompt", count: 0
  end

  test "the library requires an account" do
    get library_path

    assert_redirected_to new_session_path
  end

  private

  def create_user
    User.create!(
      email_address: "writer@example.test",
      password: "long-password",
      password_confirmation: "long-password"
    )
  end

  def sign_in(user)
    post session_path, params: { email_address: user.email_address, password: "long-password" }
  end
end
