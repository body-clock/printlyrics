require "test_helper"

# Google end to end: what the account pages render, what the callback does with
# the payload OmniAuth leaves in the request, and what a host without a client
# does instead.
class GoogleSignInFlowTest < ActionDispatch::IntegrationTest
  test "a host that cannot sign anyone in renders no Google control" do
    get new_session_path
    assert_response :success
    assert_select "form[action='/auth/google_oauth2']", count: 0
    assert_select ".account-divider", count: 0

    get new_registration_path
    assert_response :success
    assert_select "form[action='/auth/google_oauth2']", count: 0

    assert_not GoogleSignIn.configured?
  end

  test "Google is the first and loudest control on both account pages" do
    with_google_configured do
      get new_session_path
      assert_response :success
      assert_select ".account-panel > .google-sign-in .button-google.button-primary", count: 1
      assert_select ".account-panel > .google-sign-in + .account-divider", count: 1
      assert_select ".account-panel > .google-sign-in + .account-divider + form.account-form", count: 1

      get new_registration_path
      assert_response :success
      assert_select ".account-panel > .google-sign-in .button-google.button-primary", count: 1
      assert_select ".account-panel > .google-sign-in + .account-divider", count: 1
    end
  end

  test "the request phase asks Google for this host's callback" do
    with_google_configured(client_id: "probe-client-id") do
      post "/auth/google_oauth2"
    end

    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal "accounts.google.com", location.host

    params = URI.decode_www_form(location.query).to_h
    assert_equal "probe-client-id", params["client_id"]
    assert_equal "http://www.example.com/auth/google_oauth2/callback", params["redirect_uri"]
    assert_includes params["scope"], "email"
    assert_equal "select_account", params["prompt"]
  end

  test "a host without a client refuses the request phase" do
    assert_empty OmniAuth.config.allowed_request_methods

    post "/auth/google_oauth2"

    assert_response :not_found
  end

  test "a verified Google account creates an account and starts a session" do
    with_google_configured do
      with_google_auth(email: "newcomer@example.test") do
        get "/auth/google_oauth2/callback"
      end
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_select "[role=status]", /Account created/
    assert_select "[data-analytics-page-response='Account Created']", 1
    created = css_select("[data-analytics-page-response='Account Created']").first
    assert_equal "google", JSON.parse(created["data-analytics-props"])["account_method"]

    user = User.sole
    assert_equal "newcomer@example.test", user.email_address
    assert_equal [ [ "google_oauth2", "google-uid-1" ] ],
      user.identities.map { |identity| [ identity.provider, identity.uid ] }

    get library_path
    assert_response :success
    assert_select ".site-account-email", "newcomer@example.test"
  end

  test "a returning Google account signs in without a second account" do
    with_google_configured do
      with_google_auth(uid: "google-uid-known", email: "known@example.test") do
        get "/auth/google_oauth2/callback"
        assert_redirected_to root_url

        # The first callback created the account. Start the second one without
        # its session, the way a later browser arrival would.
        reset!
        get "/auth/google_oauth2/callback"
      end
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_select "[role=status]", /Signed in/
    assert_select "[data-analytics-page-response='Account Created']", count: 0
    assert_select "[data-analytics-page-response='Account Signed In']", 1
    signed_in = css_select("[data-analytics-page-response='Account Signed In']").first
    assert_equal "google", JSON.parse(signed_in["data-analytics-props"])["account_method"]
    assert_equal 1, User.count
    assert_equal 1, Identity.count

    get library_path
    assert_response :success
  end

  test "a Google sign-in does not claim an existing password account" do
    existing = User.create!(
      email_address: "known@example.test",
      password: "long-password",
      password_confirmation: "long-password"
    )

    with_google_configured do
      with_google_auth(uid: "google-uid-known", email: "known@example.test") do
        get "/auth/google_oauth2/callback"
      end
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.refused"))}/
    assert_equal 1, User.count
    assert_equal 0, existing.identities.count

    get library_path
    assert_redirected_to new_session_path
  end

  test "an unverified address is refused with a sentence rather than a session" do
    with_google_configured do
      with_google_auth(email_verified: false) do
        get "/auth/google_oauth2/callback"
      end
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.refused"))}/
    assert_equal 0, User.count
    assert_equal 0, Identity.count

    get library_path
    assert_redirected_to new_session_path
  end

  test "a callback with no payload is refused" do
    with_google_configured do
      with_no_google_payload { get "/auth/google_oauth2/callback" }
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.refused"))}/
    assert_equal 0, User.count
  end

  test "a callback Google could not complete lands on the sign-in page" do
    with_google_configured do
      get "/auth/google_oauth2/callback"
    end

    follow_redirect!
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.failed"))}/
    assert_equal 0, User.count
  end

  test "the failure path answers with the sign-in page and does not repeat the reason" do
    get "/auth/failure", params: { message: "invalid_credentials", strategy: "google_oauth2" }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.failed"))}/
    assert_no_match(/invalid_credentials/, response.body)
  end
end
