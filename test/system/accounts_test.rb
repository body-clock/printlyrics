require "application_system_test_case"

class AccountsTest < ApplicationSystemTestCase
  test "a visitor creates an account, saves a sheet, opens the library, and removes it" do
    visit root_path
    click_link "Create account"

    fill_in "user_email_address", with: "browser@example.test"
    fill_in "user_password", with: "long-password"
    fill_in "user_password_confirmation", with: "long-password"
    click_button "Create account"

    assert_text "Account created"
    assert_text "browser@example.test"

    within(".account-bar") { click_link "Your library" }
    assert_text "Your library"
    assert_text "0 of 10 saved"

    visit root_path
    fill_in "Song title", with: "Saved Song"
    fill_in "Lyrics", with: "A line kept for later"
    click_button "Generate print page"

    assert_text "Saved Song"
    click_button "Save to your library"
    assert_text "Saved to your library."

    within(".library-prompt") do
      assert_text "Saved in"
      click_link "your library"
    end
    assert_text "1 of 10 saved"
    assert_text "Saved Song"

    click_button "Remove"
    assert_text "0 of 10 saved"
    assert_text "Nothing saved yet"
  end

  test "Google is the first account control when the host can offer it" do
    with_google_configured do
      visit new_session_path

      assert_selector ".account-panel > .google-sign-in .button-google.button-primary",
        text: "Continue with Google"
      assert_selector ".account-panel > .google-sign-in + .account-divider"
    end
  end
end
