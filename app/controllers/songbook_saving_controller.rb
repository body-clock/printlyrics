class SongbookSavingController < ApplicationController
  allow_unauthenticated_access

  def show
    # The page renders the plans as controls only on a host that can sell them,
    # and every page states how payment works rather than implying one that
    # cannot happen: without a configured checkout provider the proposal wording
    # stays exactly as it reads today and no purchase control is rendered.
    @premium_checkout_available = StripeGateway.configured?
  end
end
