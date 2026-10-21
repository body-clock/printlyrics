# Where a Google sign-in lands.
#
# The middleware has already exchanged the code with Google, so the payload in
# the request is one Google signed. The callback arrives without a session —
# signing in is what a session is for — and ends by starting one, which is also
# what finishes a save the visitor began while signed out.
class OmniauthCallbacksController < ApplicationController
  def create
    sign_in = GoogleSignIn.new(request.env["omniauth.auth"])
    user = sign_in.call

    start_new_session_for(user)
    remember_page_response("Account Created") if sign_in.created?
    redirect_to after_authentication_url,
      notice: flash[:notice].presence ||
        (sign_in.created? ? t("accounts.created") : t("accounts.login.welcome_back"))
  rescue GoogleSignIn::Refused => error
    # The message names what was refused, never the payload it refused.
    Rails.logger.info("Google sign-in refused (#{error.message}).")
    redirect_to new_session_path, alert: t("accounts.google.refused")
  end

  # OmniAuth sends payloads it could not complete here, including the request
  # phase a host refuses when it cannot sign anyone in. The reason arrives in
  # the query string and is deliberately not read.
  def failure
    redirect_to new_session_path, alert: t("accounts.google.failed")
  end
end
