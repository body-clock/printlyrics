# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_23_200000) do
  create_table "feedbacks", force: :cascade do |t|
    t.string "surface", null: false
    t.string "query", limit: 200
    t.text "message"
    t.string "contact_email"
    t.boolean "verified", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reason"
    t.integer "visit_sheet_count"
    t.index ["created_at"], name: "index_feedbacks_on_created_at"
  end

  create_table "identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
  end

  create_table "lyrics", force: :cascade do |t|
    t.string "artist", limit: 200
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.text "lyrics", null: false
    t.integer "song_id"
    t.string "source_url"
    t.string "title", limit: 200
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_lyrics_on_expires_at"
    t.index ["song_id"], name: "index_lyrics_on_song_id"
    t.index ["token"], name: "index_lyrics_on_token", unique: true
  end

  create_table "premium_grants", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider", default: "stripe", null: false
    t.string "provider_ref", null: false
    t.string "kind", null: false
    t.integer "amount_cents"
    t.string "currency"
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_ref"], name: "index_premium_grants_on_provider_and_provider_ref", unique: true
    t.index ["user_id"], name: "index_premium_grants_on_user_id"
  end

  create_table "saved_items", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "item_type", null: false
    t.integer "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type", "item_id"], name: "index_saved_items_on_item"
    t.index ["user_id", "item_type", "item_id"], name: "index_saved_items_on_user_and_item", unique: true
    t.index ["user_id"], name: "index_saved_items_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "songbook_entries", force: :cascade do |t|
    t.integer "songbook_id", null: false
    t.integer "lyric_id", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "size", default: "m", null: false
    t.integer "columns", default: 1, null: false
    t.index ["lyric_id"], name: "index_songbook_entries_on_lyric_id"
    t.index ["songbook_id", "lyric_id"], name: "index_songbook_entries_on_songbook_id_and_lyric_id", unique: true
    t.index ["songbook_id", "position"], name: "index_songbook_entries_on_songbook_id_and_position", unique: true
    t.check_constraint "columns IN (1, 2)", name: "songbook_entries_columns_supported"
    t.check_constraint "size IN ('s', 'm', 'l', 'xl')", name: "songbook_entries_size_supported"
  end

  create_table "songbooks", force: :cascade do |t|
    t.string "token", null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "visitor_key"
    t.string "share_token"
    t.index ["expires_at"], name: "index_songbooks_on_expires_at"
    t.index ["share_token"], name: "index_songbooks_on_share_token", unique: true
    t.index ["token"], name: "index_songbooks_on_token", unique: true
    t.index ["user_id"], name: "index_songbooks_on_user_id"
    t.index ["visitor_key", "created_at"], name: "index_songbooks_on_visitor_key_and_created_at"
  end

  create_table "songs", force: :cascade do |t|
    t.string "album"
    t.string "artist", null: false
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "last_verified_at"
    t.integer "print_page_count", default: 0, null: false
    t.integer "source_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["source_id"], name: "index_songs_on_source_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "premium_until"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["stripe_customer_id"], name: "index_users_on_stripe_customer_id", unique: true
  end

  add_foreign_key "identities", "users"
  add_foreign_key "lyrics", "songs"
  add_foreign_key "premium_grants", "users"
  add_foreign_key "saved_items", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "songbook_entries", "lyrics", on_delete: :cascade
  add_foreign_key "songbook_entries", "songbooks", on_delete: :cascade
  add_foreign_key "songbooks", "users"
end
