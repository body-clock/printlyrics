class MatchLyricMetadataBounds < ActiveRecord::Migration[8.1]
  # SQLite ignores the length, but the declared bounds keep the schema
  # honest about the model validations.
  def up
    change_column :lyrics, :title, :string, limit: 200
    change_column :lyrics, :artist, :string, limit: 200
  end

  def down
    change_column :lyrics, :title, :string, limit: nil
    change_column :lyrics, :artist, :string, limit: nil
  end
end
