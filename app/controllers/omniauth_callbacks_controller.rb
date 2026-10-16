# Where a Google sign-in lands.
#
# The middleware has already exchanged the code with Google by the time this
# runs, so the payload left in the request is one Google signed: nothing here
# takes the browser's word for who the visitor is. The callback arrives without a
# session — signing in is what a session is for — and ends by starting one, which
# is also what claims the songbooks this browser made as a guest.
class OmniauthCallbacksController < ApplicationController
  allow_unauthenticated_access only: %i[create failure]

  def create
    sign_in = GoogleSignIn.new(request.env["omniauth.auth"])
    user = sign_in.call

    start_new_session_for(user)
    # An account Google created is an account created: the same event the password
    # form reports, on the page the visitor lands on.
    if sign_in.created?
      session[:analytics_page_responses] = { "Account Created" => SecureRandom.hex(16) }
    end

    redirect_to after_authentication_url
  rescue GoogleSignIn::Refused => error
    # The message names what was refused, never the payload it refused.
    Rails.logger.info("Google sign-in refused (#{error.message}).")
    redirect_to new_session_path, alert: t("accounts.google.refused")
  end

  # OmniAuth sends a payload it could not complete here, including the request
  # phase this host refuses when it cannot sign anyone in. The reason it names
  # arrives in the query string and is deliberately not read: the visitor gets one
  # sentence, and a value from the URL is not written to a log.
  def failure
    redirect_to new_session_path, alert: t("accounts.google.failed")
  end
end
