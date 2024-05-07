class CreateLibraries < ActiveRecord::Migration[7.2]
  def change
    create_table :libraries do |t|
      t.string :title, null: false, default: ''
      t.string :author, null: false, default: ''
      t.string :type, null: false, default: ''
      t.text :description, null: false, default: ''
      t.boolean :audio, null: true, default: false
      t.boolean :video, null: false, default: true
      t.boolean :archive, null: false, default: false
      t.string :thumbnail_url, null: false, default: ''

      t.timestamps
    end
  end
end
