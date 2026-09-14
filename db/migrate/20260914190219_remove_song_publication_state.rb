class RemoveSongPublicationState < ActiveRecord::Migration[8.1]
  # The public song catalog was removed. These columns only ever described
  # whether a song's page was published or withdrawn, so nothing reads them
  # now. Songs carry source metadata and a private demand count.
  def change
    remove_column :songs, :indexable_at, :datetime
    remove_column :songs, :unavailable_at, :datetime
  end
end
