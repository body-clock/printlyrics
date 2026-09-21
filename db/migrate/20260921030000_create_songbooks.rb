class CreateSongbooks < ActiveRecord::Migration[8.1]
  def change
    create_table :songbooks do |t|
      t.string :token, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :songbooks, :token, unique: true
    add_index :songbooks, :expires_at

    create_table :songbook_entries do |t|
      # Songbooks and entries are deleted in bulk by the retention task, which
      # bypasses dependent callbacks, so the database owns the cascade.
      t.references :songbook, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :lyric, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false

      t.timestamps
    end

    add_index :songbook_entries, [ :songbook_id, :position ], unique: true
    add_index :songbook_entries, [ :songbook_id, :lyric_id ], unique: true
  end
end
