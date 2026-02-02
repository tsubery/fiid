class AddPriorityToFeeds < ActiveRecord::Migration[7.1]
  def change
    add_column :feeds, :priority, :integer, default: 100, null: false
    add_index :feeds, :priority
  end
end
