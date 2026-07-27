class AddRetentionToLyrics < ActiveRecord::Migration[8.1]
  def up
    add_column :lyrics, :source_url, :string
    add_column :lyrics, :expires_at, :datetime
    execute "UPDATE lyrics SET expires_at = #{connection.quote(180.days.from_now)}"
    change_column_null :lyrics, :expires_at, false
    add_index :lyrics, :expires_at
  end

  def down
    remove_index :lyrics, :expires_at
    remove_column :lyrics, :expires_at
    remove_column :lyrics, :source_url
  end
end
