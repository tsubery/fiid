class AddArchivedToMediaItems < ActiveRecord::Migration[7.1]
  def change
    add_column :media_items, :archived, :boolean, default: false, null: false
    add_index :media_items, :archived, where: "archived = false"
  end
end
