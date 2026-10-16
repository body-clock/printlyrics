class AccountSongbooksController < ApplicationController
  def index
    @songbooks = current_user.songbooks.active.includes(:entries).order(created_at: :desc)
    # The visitor arrives here from Stripe's checkout page with the payment still
    # unconfirmed: this page says so, because the webhook is what grants access
    # and a redirect is not evidence of a payment.
    @checkout_returned = params[:checkout] == "return"
    # Nothing to manage without the customer the account checked out with, and a
    # host that cannot sell renders no such control either.
    @billing_portal_available = StripeGateway.configured? && current_user.stripe_customer_id.present?
    @analytics_page_responses = { "Account Library Opened" => SecureRandom.hex(16) }
  end
end
