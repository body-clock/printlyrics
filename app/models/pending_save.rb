# The one item a signed-out visitor asked to save.
#
# Saving signs a visitor in first, which means the request that carried the
# intent cannot finish it: the redirect to Google or the password form leaves
# the original POST behind. The session holds the item's type and token across
# that detour, and the first authenticated request claims it.
class PendingSave
  SESSION_KEY = :pending_save

  def self.stash(session, item_type:, token:)
    return unless SavedItem::ITEM_TYPES.include?(item_type)

    session[SESSION_KEY] = { "item_type" => item_type, "token" => token }
  end

  # Returns the saved page on success, :limit_reached when the shelf is full,
  # and nil when there was nothing waiting or the page no longer exists.
  def self.claim(session:, user:)
    pending = session.delete(SESSION_KEY)
    return unless pending.is_a?(Hash)

    item_class = SavedItem.item_class(pending["item_type"])
    return unless item_class

    item = item_class.active.find_by(token: pending["token"])
    return unless item

    SavedItem.add(user: user, item: item)
    item
  rescue SavedItem::LimitReached
    :limit_reached
  end
end
