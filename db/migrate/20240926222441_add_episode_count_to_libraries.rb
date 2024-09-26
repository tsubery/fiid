class AddEpisodeCountToLibraries < ActiveRecord::Migration[7.2]
  def change
    add_column :libraries, :episode_count, :integer, default: Library::DEFAULT_EPISODE_COUNT, null: false
  end
end
