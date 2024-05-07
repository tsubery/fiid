class AddTitleDescriptionThumbnailUrlToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :description, :string, null: false, default: ''
    add_column :feeds, :title, :string, null: false, default: ''
    add_column :feeds, :thumbnail_url, :string, null: false, default: ''
    add_column :media_items, :reachable, :boolean, null: false, default: true
  end
end
