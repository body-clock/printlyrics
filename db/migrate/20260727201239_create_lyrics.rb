class CreateLyrics < ActiveRecord::Migration[8.1]
  def change
    create_table :lyrics do |t|
      t.string :token, null: false
      t.string :title
      t.string :artist
      t.text :lyrics, null: false

      t.timestamps
    end

    add_index :lyrics, :token, unique: true
  end
end
