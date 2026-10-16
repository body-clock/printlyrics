class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid, null: false

      t.timestamps
    end

    # One account per third-party identity. The index is the invariant rather
    # than the validation alone, because two callbacks for the same Google
    # account can arrive together.
    add_index :identities, [ :provider, :uid ], unique: true
  end
end
