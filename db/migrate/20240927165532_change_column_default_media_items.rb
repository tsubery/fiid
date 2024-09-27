class ChangeColumnDefaultMediaItems < ActiveRecord::Migration[8.0]
  def change
    change_column_default :media_items, :reachable, from: true, to: nil
    change_column_null :media_items, :reachable, true
  end
end
