class AddStripeCustomerIdToUsers < ActiveRecord::Migration[8.1]
  def change
    # The customer a visitor's checkouts and billing portal belong to. Unique,
    # because two accounts sharing one Stripe customer would share its invoices.
    add_column :users, :stripe_customer_id, :string
    add_index :users, :stripe_customer_id, unique: true

    # The subscription the monthly plan is currently billed by. The ledger
    # records every payment; this is the single live reference the account holds
    # while a subscription runs, and `customer.subscription.deleted` clears it.
    add_column :users, :stripe_subscription_id, :string
  end
end
