require "test_helper"

# Google sign-in end to end: what the two account pages render, what the callback
# does with the payload OmniAuth leaves in the request, and what a host that cannot
# sign anyone in does instead. OmniAuth answers with a payload rather than calling
# Google, so the middleware and the callback are the ones that run in production.
class GoogleSignInFlowTest < ActionDispatch::IntegrationTest
  test "a host that cannot sign anyone in renders no Google control" do
    get new_session_path
    assert_response :success
    assert_select "form[action='/auth/google_oauth2']", count: 0

    get new_registration_path
    assert_response :success
    assert_select "form[action='/auth/google_oauth2']", count: 0

    assert_not GoogleSignIn.configured?
  end

  test "the request phase asks Google for the callback this host registers" do
    with_google_configured(client_id: "probe-client-id") do
      post "/auth/google_oauth2"
    end

    assert_response :redirect
    location = URI.parse(response.location)
    assert_equal "accounts.google.com", location.host

    params = URI.decode_www_form(location.query).to_h
    assert_equal "probe-client-id", params["client_id"]
    # Google compares this string exactly, host and path alike, so the console's
    # authorized redirect URI has to be this one — /auth/google_oauth2/callback is
    # the strategy's default and this application does not configure another.
    assert_equal "http://www.example.com/auth/google_oauth2/callback", params["redirect_uri"]
    assert_includes params["scope"], "email"
    assert_equal "select_account", params["prompt"]
  end

  test "a host that cannot sign anyone in refuses the request phase outright" do
    # The middleware answers POST alone, and a host with no client refuses the
    # method, so no one is sent to Google with an empty client ID.
    assert_empty OmniAuth.config.allowed_request_methods

    post "/auth/google_oauth2"

    assert_response :not_found
  end

  test "the control posts the request phase and leaves Turbo out of it" do
    with_google_configured do
      get new_session_path
    end

    assert_response :success
    assert_select "button", text: I18n.t("accounts.google.continue")
    # The middleware answers with a redirect to Google, so the browser has to
    # follow it itself: a Turbo fetch cannot take the visitor there and back. A
    # form is also what carries the authenticity token
    # omniauth-rails_csrf_protection checks before the middleware runs — the token
    # is not asserted here because the test environment turns Rails' forgery
    # protection, and with it the check, off.
    assert_select "form[action='/auth/google_oauth2'][method=post][data-turbo='false']", count: 1
  end

  test "the register page offers the same control" do
    with_google_configured do
      get new_registration_path
    end

    assert_response :success
    assert_select "form[action='/auth/google_oauth2']", count: 1
  end

  test "a verified Google account signs in and creates the account it needs" do
    with_google_configured do
      with_google_auth(email: "newcomer@example.test") do
        get "/auth/google_oauth2/callback"
      end
    end

    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
    # An account Google created is an account created: the same event the password
    # form reports, on the page the visitor lands on.
    assert_select "[data-analytics-page-response=?]", "Account Created", count: 1

    user = User.sole
    assert_equal "newcomer@example.test", user.email_address
    assert_equal [ [ "google_oauth2", "google-uid-1" ] ], user.identities.map { |i| [ i.provider, i.uid ] }

    # The callback started the session, which is what makes the library available.
    get account_songbooks_path
    assert_response :success
    assert_select "p", /0 of #{User::FREE_SONGBOOK_LIMIT} songbooks stored/
  end

  test "a returning account signs in without a second account or a creation event" do
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

    assert_redirected_to root_url
    follow_redirect!
    assert_select "[data-analytics-page-response=?]", "Account Created", count: 0
    assert_equal 1, User.count
    assert_equal existing, Identity.sole.user

    get account_songbooks_path
    assert_response :success
  end

  test "an unverified address is refused with a sentence rather than a session" do
    with_google_configured do
      with_google_auth(email_verified: false) do
        get "/auth/google_oauth2/callback"
      end
    end

    assert_redirected_to new_session_path
    follow_redirect!
    # The alert carries the message and its own mark, so the page is asked for the
    # sentence rather than for that exact text node.
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.refused"))}/
    assert_equal 0, User.count
    assert_equal 0, Identity.count

    get account_songbooks_path
    assert_redirected_to new_session_path
  end

  test "a callback that carries no payload is refused" do
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
      # No code in the query string is what a declined consent screen sends back:
      # the middleware fails the callback before this application sees a payload,
      # and answers with a redirect to the failure path this application routes.
      get "/auth/google_oauth2/callback"
    end

    follow_redirect!
    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.failed"))}/
    assert_equal 0, User.count
  end

  test "the failure path OmniAuth redirects to answers with the sign-in page" do
    get "/auth/failure", params: { message: "invalid_credentials", strategy: "google_oauth2" }

    assert_redirected_to new_session_path
    follow_redirect!
    assert_select "[role=alert]", /#{Regexp.escape(I18n.t("accounts.google.failed"))}/
    # The reason arrived in the query string and is deliberately not repeated: the
    # page says one sentence and the log is not written from a URL.
    assert_no_match(/invalid_credentials/, response.body)
  end
end
