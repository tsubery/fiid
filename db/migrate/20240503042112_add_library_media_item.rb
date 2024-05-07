class AddLibraryMediaItem < ActiveRecord::Migration[7.2]
  def change
    create_table :libraries_media_items do |t|
      t.references :library, null: false
      t.references :media_item, null: false

      t.timestamps
    end
    add_foreign_key :libraries_media_items, :libraries, column: :library_id, on_delete: :cascade
    add_foreign_key :libraries_media_items, :media_items, column: :media_item_id, on_delete: :cascade
    add_index :libraries_media_items, [:library_id, :media_item_id], unique: true
  end
end
