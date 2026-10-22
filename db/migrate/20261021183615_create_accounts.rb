class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    # A developer who ran the unmerged premium branch has these tables already.
    # The migration still has to build them from nothing on a fresh host, so it
    # creates what is missing and adds the invariants independently.
    create_table :users, if_not_exists: true do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email_address, unique: true, if_not_exists: true

    create_table :sessions, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :sessions, :user_id, if_not_exists: true

    create_table :identities, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false
      t.timestamps
    end
    add_index :identities, :user_id, if_not_exists: true

    # One account per third-party identity. Two callbacks for the same Google
    # account can arrive together, so the index is the invariant rather than
    # the model validation alone.
    add_index :identities, [ :provider, :uid ], unique: true, if_not_exists: true

    create_table :saved_items, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.references :item, polymorphic: true, null: false
      t.timestamps
    end

    # The same sheet belongs to a library once, and the database refuses a
    # second row if two requests race past the model's check.
    add_index :saved_items, [ :user_id, :item_type, :item_id ],
      unique: true,
      if_not_exists: true,
      name: "index_saved_items_on_user_and_item"

    # A nil expiry is a sheet an account has kept. Anonymous pages still get the
    # 180-day window; removing an item from a library puts it back on that clock.
    change_column_null :lyrics, :expires_at, true
    change_column_null :songbooks, :expires_at, true
  end
end
