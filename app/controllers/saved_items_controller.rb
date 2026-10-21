class SavedItemsController < ApplicationController
  before_action :require_authentication, except: :create

  def index
    # The shelf is capped, so loading a user's saved items and their pages is
    # bounded work; a missing item is skipped rather than rendered as a link.
    @saved_items = current_user.saved_items.includes(:item).order(created_at: :desc)
      .select { |saved_item| saved_item.item }
  end

  def create
    item = requested_item
    return redirect_to(root_path, alert: t("accounts.library.missing")) unless item

    unless authenticated?
      PendingSave.stash(session, item_type: item.class.name, token: item.token)
      session[:return_to_after_authenticating] = polymorphic_path(item)
      return redirect_to new_session_path
    end

    if current_user.saved?(item)
      redirect_to polymorphic_path(item), notice: t("accounts.library.already_saved")
    else
      SavedItem.add(user: current_user, item: item)
      remember_page_response("Library Item Saved",
        saved_item_type: item.class.name.underscore,
        save_source: "library")
      redirect_to polymorphic_path(item), notice: t("accounts.library.saved")
    end
  rescue SavedItem::LimitReached
    redirect_to library_path, alert: t("accounts.library.full", limit: SavedItem::LIMIT)
  end

  def destroy
    item = current_user.saved_items.find(params[:id])
    item.release!
    redirect_to library_path, notice: t("accounts.library.removed")
  end

  private

  def requested_item
    item_class = SavedItem.item_class(params[:item_type].to_s)
    return unless item_class

    item_class.active.find_by(token: params[:token].to_s)
  end
end
