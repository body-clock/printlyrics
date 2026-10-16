# Opens the Stripe-hosted page where an account changes or cancels what it pays
# for.
#
# There is nothing to manage without a customer, and a customer only exists once
# the account has started a checkout, so both halves are required before the
# redirect: the control that posts here is rendered under the same conditions.
class BillingPortalsController < ApplicationController
  # Tests replace the Stripe client through this seam, so no test reaches Stripe.
  class_attribute :stripe_gateway_factory, default: -> { StripeGateway.new }

  def create
    customer_id = current_user.stripe_customer_id

    if customer_id.blank? || !stripe_gateway.configured?
      return redirect_to account_songbooks_path, alert: t("premium.billing_portal.unavailable")
    end

    redirect_to portal_url(customer_id), allow_other_host: true
  rescue StripeGateway::ServiceError => error
    Rails.logger.warn("Stripe billing portal was not opened (#{error.message}).")
    redirect_to account_songbooks_path, alert: t("premium.billing_portal.failed")
  end

  private

  def portal_url(customer_id)
    stripe_gateway.create_billing_portal_session(
      customer_id: customer_id,
      return_url: account_songbooks_url
    )
  end

  def stripe_gateway
    @stripe_gateway ||= self.class.stripe_gateway_factory.call
  end
end
