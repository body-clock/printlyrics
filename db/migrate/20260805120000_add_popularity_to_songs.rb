class AddPopularityToSongs < ActiveRecord::Migration[8.1]
  def change
    add_column :songs, :apple_music_id, :string
    add_column :songs, :apple_music_url, :string
    add_column :songs, :popular_rank, :integer
    add_column :songs, :popular_refreshed_at, :datetime

    add_index :songs, :apple_music_id
    add_index :songs, :popular_rank, unique: true, where: "popular_rank IS NOT NULL"
  end
end
