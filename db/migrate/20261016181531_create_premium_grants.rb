class CreatePremiumGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :premium_grants do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false, default: "stripe"
      t.string :provider_ref, null: false
      t.string :kind, null: false
      t.integer :amount_cents
      t.string :currency
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.timestamps
    end

    # The idempotency key: one row per payment this application has already
    # granted, so a webhook Stripe retries extends nothing a second time.
    add_index :premium_grants, [ :provider, :provider_ref ], unique: true
  end
end
