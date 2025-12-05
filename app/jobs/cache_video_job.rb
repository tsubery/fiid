class CacheVideoJob < ApplicationJob
  queue_as :default

  TWO_WEEKS = 14 * 24 * 60 * 60
  def perform(media_item_id)
    MediaItem.find(media_item_id).cache_video
    now = Time.now
    %w[article video].each do |type|
      Dir.glob("public/**/#{type}").each do |relative_path|
        if File.stat(relative_path).atime < (now - TWO_WEEKS)
          File.unlink(relative_path)
        end
      end
    end
  end
end
