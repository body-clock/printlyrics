class PasswordsController < ApplicationController
  before_action :set_user_by_token, only: %i[edit update]
  rate_limit to: 10, within: 3.minutes, only: :create,
    with: -> { redirect_to new_password_path, alert: t("accounts.password_reset.rate_limited") }

  def new
  end

  def create
    email = params[:email_address].to_s.strip.downcase
    if user = User.find_by(email_address: email)
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: t("accounts.password_reset.sent")
  end

  def edit
  end

  def update
    if @user.update(password_params)
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: t("accounts.password_reset.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveRecord::RecordNotFound, ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: t("accounts.password_reset.invalid")
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
