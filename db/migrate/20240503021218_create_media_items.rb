class CreateMediaItems < ActiveRecord::Migration[7.2]
  def change
    create_table :media_items do |t|
      t.string :url, null: false
      t.integer :duration_seconds
      t.string :title, null: false, default: ''
      t.text :description, null: false, default: ''
      t.string :author, null: false, default: ''
      t.string :thumbnail_url, null: false, default: ''
      t.string :mime_type, null: false, default: ''
      t.timestamp :published_at
      t.references :feed, null: false
      t.string :youtube_video_id, null: false, default: ''
      t.string :copy_url, null: false, default: ''

      t.timestamps
    end
    add_index :media_items, [:feed_id, :url], unique: true
    add_foreign_key :media_items, :feeds, on_delete: :cascade
  end
end
