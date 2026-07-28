class AddSongToLyrics < ActiveRecord::Migration[8.1]
  def change
    add_reference :lyrics, :song, null: true, foreign_key: true
  end
end
