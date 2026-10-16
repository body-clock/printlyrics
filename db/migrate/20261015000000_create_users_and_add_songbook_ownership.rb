class CreateUsersAndAddSongbookOwnership < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.datetime :premium_until
      t.timestamps
    end
    add_index :users, :email_address, unique: true

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_reference :songbooks, :user, foreign_key: true
    change_column_null :songbooks, :expires_at, true
    add_column :songbooks, :visitor_key, :string
    add_index :songbooks, [ :visitor_key, :created_at ]
    add_column :songbooks, :share_token, :string
    add_index :songbooks, :share_token, unique: true
    change_column_null :lyrics, :expires_at, true
  end
end
