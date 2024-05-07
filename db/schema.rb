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

ActiveRecord::Schema[7.2].define(version: 2024_05_22_184905) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness",
                                                             unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "feeds", force: :cascade do |t|
    t.string "url", null: false
    t.string "type", default: "", null: false
    t.datetime "last_sync", precision: nil
    t.text "fetch_error_message", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "description", default: "", null: false
    t.string "title", default: "", null: false
    t.string "thumbnail_url", default: "", null: false
    t.string "etag", default: "", null: false
    t.string "last_modified", default: "", null: false
    t.index ["url"], name: "index_feeds_on_url"
  end

  create_table "feeds_libraries", force: :cascade do |t|
    t.bigint "feed_id", null: false
    t.bigint "library_id", null: false
    t.json "filter", default: "{}", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feed_id"], name: "index_feeds_libraries_on_feed_id"
    t.index ["library_id"], name: "index_feeds_libraries_on_library_id"
  end

  create_table "libraries", force: :cascade do |t|
    t.string "title", default: "", null: false
    t.string "author", default: "", null: false
    t.string "type", default: "", null: false
    t.text "description", default: "", null: false
    t.boolean "audio", default: false
    t.boolean "video", default: true, null: false
    t.boolean "archive", default: false, null: false
    t.string "thumbnail_url", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "libraries_media_items", force: :cascade do |t|
    t.bigint "library_id", null: false
    t.bigint "media_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["library_id", "media_item_id"], name: "index_libraries_media_items_on_library_id_and_media_item_id",
                                             unique: true
    t.index ["library_id"], name: "index_libraries_media_items_on_library_id"
    t.index ["media_item_id"], name: "index_libraries_media_items_on_media_item_id"
  end

  create_table "media_items", force: :cascade do |t|
    t.string "url", null: false
    t.integer "duration_seconds"
    t.string "title", default: "", null: false
    t.text "description", default: "", null: false
    t.string "author", default: "", null: false
    t.string "thumbnail_url", default: "", null: false
    t.string "mime_type", default: "", null: false
    t.datetime "published_at", precision: nil
    t.bigint "feed_id", null: false
    t.string "copy_url", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "reachable", default: true, null: false
    t.string "guid", null: false
    t.index ["feed_id", "guid"], name: "index_media_items_on_feed_id_and_guid", unique: true
    t.index ["feed_id"], name: "index_media_items_on_feed_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "feeds_libraries", "feeds", on_delete: :cascade
  add_foreign_key "feeds_libraries", "libraries", on_delete: :cascade
  add_foreign_key "libraries_media_items", "libraries", on_delete: :cascade
  add_foreign_key "libraries_media_items", "media_items", on_delete: :cascade
  add_foreign_key "media_items", "feeds", on_delete: :cascade
end
