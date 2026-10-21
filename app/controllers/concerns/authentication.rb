# Optional accounts: the public tool never requires one, and a controller that
# owns an account surface opts into `require_authentication`.
module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :authenticated?
  end

  private

  def current_user
    resume_session&.user
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication
    resume_session || request_authentication
  end

  def resume_session
    return Current.session if Current.session
    return @resumed_session if defined?(@resumed_session)

    @resumed_session = Current.session = find_session_by_cookie
  end

  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id])
  end

  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_path
  end

  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  def start_new_session_for(user)
    user.sessions.create!.tap do |session_record|
      Current.session = session_record
      cookies.signed.permanent[:session_id] = {
        value: session_record.id,
        httponly: true,
        same_site: :lax,
        secure: Rails.env.production?
      }
      finish_pending_save_for(user)
    end
  end

  def terminate_session
    Current.session&.destroy
    Current.session = nil
    @resumed_session = nil
    cookies.delete(:session_id)
  end

  # The click that sent a signed-out visitor through sign-in is finished here,
  # so the detour costs them a sign-in rather than a second click.
  def finish_pending_save_for(user)
    case PendingSave.claim(session: session, user: user)
    when :limit_reached
      flash[:alert] = t("accounts.library.full_after_sign_in", limit: SavedItem::LIMIT)
    when Lyric, Songbook
      flash[:notice] = t("accounts.library.saved")
      remember_page_response("Library Item Saved")
    end
  end
end
