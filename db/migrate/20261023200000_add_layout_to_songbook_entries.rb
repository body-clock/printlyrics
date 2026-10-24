class AddLayoutToSongbookEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :songbook_entries, :size, :string, null: false, default: "m"
    add_column :songbook_entries, :columns, :integer, null: false, default: 1

    add_check_constraint :songbook_entries,
      "size IN ('s', 'm', 'l', 'xl')",
      name: "songbook_entries_size_supported"
    add_check_constraint :songbook_entries,
      "columns IN (1, 2)",
      name: "songbook_entries_columns_supported"
  end
end
