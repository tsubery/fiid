class CacheVideoJob < ApplicationJob
  queue_as :default

  TWO_DAYS = 2 * 24 * 60 * 60
  def perform(media_item_id)
    video = MediaItem.find(media_item_id)
    video.transaction do
      video.lock!
      video.cache_video
    end

    now = Time.now
    %w[article video].each do |type|
      Dir.glob("public/**/#{type}").each do |relative_path|
        if File.stat(relative_path).atime < (now - TWO_DAYS)
          File.unlink(relative_path)
        end
      end
    end
  end
end
