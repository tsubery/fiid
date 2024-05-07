class CreateFeeds < ActiveRecord::Migration[7.2]
  def change
    create_table :feeds do |t|
      t.string :url, null: false, index: true
      t.string :type, null: false, default: ''
      t.timestamp :last_sync
      t.text :fetch_error_message, null: false, default: ''

      t.timestamps
    end
  end
end
