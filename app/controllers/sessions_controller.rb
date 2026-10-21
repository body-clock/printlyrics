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
      redirect_to after_authentication_url,
        notice: flash[:notice].presence || t("accounts.login.welcome_back")
    else
      redirect_to new_session_path, alert: t("accounts.login.failure")
    end
  end

  def destroy
    terminate_session
    redirect_to root_path, status: :see_other, notice: t("accounts.logout_done")
  end
end
