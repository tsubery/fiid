class CreateFeedLibraries < ActiveRecord::Migration[7.2]
  def change
    create_table :feeds_libraries do |t|
      t.references :feed, null: false
      t.references :library, null: false
      t.json :filter, null: false, default: '{}'

      t.timestamps
    end
    add_foreign_key :feeds_libraries, :feeds, on_delete: :cascade
    add_foreign_key :feeds_libraries, :libraries, on_delete: :cascade
  end
end
