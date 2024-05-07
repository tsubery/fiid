class AddEtagToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :etag, :string, null: false, default: ''
    add_column :feeds, :last_modified, :string, null: false, default: ''
  end
end
