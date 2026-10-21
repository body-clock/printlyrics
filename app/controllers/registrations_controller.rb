class RegistrationsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_registration_path, alert: t("accounts.register.rate_limited") }

  def new
    return redirect_to library_path if authenticated?

    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      start_new_session_for(@user)
      remember_page_response("Account Created", account_method: "password")
      redirect_to after_authentication_url,
        notice: flash[:notice].presence || t("accounts.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
