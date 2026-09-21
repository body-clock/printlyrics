class DropSongSlugAndUnusedIndex < ActiveRecord::Migration[8.1]
  # Songs have no public page since the catalog was removed, so the slug only
  # ever fed `Song#to_param` for URLs that no longer exist. `last_verified_at`
  # still records metadata refreshes, but the verifier that queried it by index
  # is gone, so the index has no reader.
  def up
    remove_index :songs, :slug
    remove_column :songs, :slug
    remove_index :songs, :last_verified_at
  end

  def down
    add_column :songs, :slug, :string
    add_index :songs, :slug, unique: true
    add_index :songs, :last_verified_at
  end
end
