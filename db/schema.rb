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

ActiveRecord::Schema[8.1].define(version: 2026_07_27_210000) do
  create_table "lyrics", force: :cascade do |t|
    t.string "artist"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.text "lyrics", null: false
    t.string "source_url"
    t.string "title"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_lyrics_on_expires_at"
    t.index ["token"], name: "index_lyrics_on_token", unique: true
  end
end
