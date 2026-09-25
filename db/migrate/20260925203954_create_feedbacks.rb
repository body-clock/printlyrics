class CreateFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :feedbacks do |t|
      # Which form the visitor used: the search-miss prompt on the entry panel,
      # or the feedback page.
      t.string :surface, null: false
      # The song the visitor searched for and could not find, carried over from
      # the search field. Nil on the feedback page, where the note is the whole
      # submission.
      t.string :query, limit: 200
      t.text :message
      # Given only when the visitor asks for a reply, and the only field here
      # that identifies anyone.
      t.string :contact_email
      # Whether Turnstile confirmed a person. The gate refuses any challenge it
      # cannot confirm, so a stored row is verified by construction and this
      # records that provenance.
      t.boolean :verified, null: false, default: false

      t.timestamps
    end

    add_index :feedbacks, :created_at
  end
end
