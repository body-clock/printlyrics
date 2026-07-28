class CreateSongs < ActiveRecord::Migration[8.1]
  def change
    create_table :songs do |t|
      t.integer :source_id, null: false
      t.string :slug, null: false
      t.string :title, null: false
      t.string :artist, null: false
      t.string :album
      t.integer :duration_seconds
      t.integer :print_page_count, null: false, default: 0
      t.datetime :indexable_at
      t.datetime :last_verified_at
      t.datetime :unavailable_at

      t.timestamps
    end

    add_index :songs, :source_id, unique: true
    add_index :songs, :slug, unique: true
    add_index :songs, [ :indexable_at, :unavailable_at ]
    add_index :songs, :last_verified_at
  end
end
