class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_session_path, alert: t("accounts.login.rate_limited") }

  def new
    redirect_to library_path if authenticated?
  end

  def create
    email = params[:email_address].to_s.strip.downcase

    if user = User.authenticate_by(email_address: email, password: params[:password].to_s)
      start_new_session_for(user)
      remember_page_response("Account Signed In", account_method: "password")
      redirect_to after_authentication_url,
        notice: flash[:notice].presence || t("accounts.login.welcome_back")
    else
      @sign_in_failed = true
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    destination = session.delete(:return_to_after_authenticating) || root_path
    session.delete(PendingSave::SESSION_KEY)
    if params[:cancel] == "true"
      redirect_to destination, status: :see_other
    else
      terminate_session
      redirect_to root_path, status: :see_other, notice: t("accounts.logout_done")
    end
  end
end
