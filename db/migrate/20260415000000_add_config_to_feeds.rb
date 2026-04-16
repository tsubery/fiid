class AddConfigToFeeds < ActiveRecord::Migration[8.0]
  def change
    add_column :feeds, :config, :jsonb, null: false, default: {}
  end
end
