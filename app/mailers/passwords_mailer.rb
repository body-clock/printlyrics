class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    @reset_url = edit_password_url(token: user.password_reset_token)

    mail subject: t("accounts.password_reset.mail_subject"), to: user.email_address
  end
end
