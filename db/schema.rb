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

ActiveRecord::Schema[8.1].define(version: 2026_07_28_130100) do
  create_table "lyrics", force: :cascade do |t|
    t.string "artist"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.text "lyrics", null: false
    t.integer "song_id"
    t.string "source_url"
    t.string "title"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_lyrics_on_expires_at"
    t.index ["song_id"], name: "index_lyrics_on_song_id"
    t.index ["token"], name: "index_lyrics_on_token", unique: true
  end

  create_table "songs", force: :cascade do |t|
    t.string "album"
    t.string "artist", null: false
    t.datetime "created_at", null: false
    t.integer "duration_seconds"
    t.datetime "indexable_at"
    t.datetime "last_verified_at"
    t.integer "print_page_count", default: 0, null: false
    t.string "slug", null: false
    t.integer "source_id", null: false
    t.string "title", null: false
    t.datetime "unavailable_at"
    t.datetime "updated_at", null: false
    t.index ["indexable_at", "unavailable_at"], name: "index_songs_on_indexable_at_and_unavailable_at"
    t.index ["last_verified_at"], name: "index_songs_on_last_verified_at"
    t.index ["slug"], name: "index_songs_on_slug", unique: true
    t.index ["source_id"], name: "index_songs_on_source_id", unique: true
  end

  add_foreign_key "lyrics", "songs"
end
