class AddGuidToMediaItems < ActiveRecord::Migration[7.2]
  def change
    add_column :media_items, :guid, :string
    execute "UPDATE media_items set guid = url;"
    remove_index :media_items, [:feed_id, :url], unique: true
    add_index :media_items, [:feed_id, :guid], unique: true
    change_column_null :media_items, :guid, false
    remove_column :media_items, :youtube_video_id
  end
end
