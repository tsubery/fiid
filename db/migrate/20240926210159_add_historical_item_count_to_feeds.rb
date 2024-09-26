class AddHistoricalItemCountToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :historical_item_count, :integer, default: 0, null: false
  end
end
