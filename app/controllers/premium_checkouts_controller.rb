# Starts a Stripe Checkout for one of the two premium plans.
#
# This action takes no payment and grants no access: it opens a session, sends the
# visitor to Stripe, and comes back. What the visit bought is decided by the
# webhook that Stripe signs afterwards, so nothing here is worth anything to
# someone who never pays.
class PremiumCheckoutsController < ApplicationController
  # Tests replace the Stripe client through this seam, so no test reaches Stripe.
  class_attribute :stripe_gateway_factory, default: -> { StripeGateway.new }

  def create
    plan = params[:plan].to_s

    unless PremiumGrant::KINDS.include?(plan)
      return redirect_to save_songbooks_path, alert: t("premium.checkout.unknown_plan")
    end

    # A host that cannot sell renders no control for this action; this is the
    # refusal behind the missing control, and it implies no payment either.
    unless stripe_gateway.configured?
      return redirect_to save_songbooks_path, alert: t("premium.checkout.unavailable")
    end

    redirect_to checkout_url(plan), allow_other_host: true
  rescue StripeGateway::ServiceError => error
    Rails.logger.warn("Stripe checkout was not started (#{error.message}).")
    redirect_to save_songbooks_path, alert: t("premium.checkout.failed")
  end

  private

  # The visitor's own id travels with the session, which is how the webhook finds
  # the account to grant when the payment confirms. The success URL is the
  # library, not this action: it says the payment is being confirmed, and it can
  # be followed without paying.
  def checkout_url(plan)
    stripe_gateway.create_checkout(
      plan: plan,
      customer_id: current_user.stripe_customer_id.presence || create_stripe_customer,
      success_url: account_songbooks_url(checkout: "return"),
      cancel_url: save_songbooks_url,
      reference: current_user.id.to_s
    )
  end

  # A customer is created on the first checkout and kept: every later payment,
  # invoice, and billing portal session for this account hangs from it.
  def create_stripe_customer
    stripe_gateway.create_customer(email: current_user.email_address).tap do |customer_id|
      current_user.update!(stripe_customer_id: customer_id)
    end
  end

  def stripe_gateway
    @stripe_gateway ||= self.class.stripe_gateway_factory.call
  end

  # The plan controls sit on a page a signed-out visitor can read, so the
  # sign-in this action requires has to come back to that page: sending the
  # visitor to this action's own URL would be a GET at a route that answers to
  # POST alone. The plan they chose is one click away from where they land.
  def request_authentication
    session[:return_to_after_authenticating] = save_songbooks_url
    redirect_to new_session_path
  end
end
