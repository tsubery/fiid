class CacheVideoJob < ApplicationJob
  queue_as :videos

  TWO_DAYS = 2 * 24 * 60 * 60
  def perform(media_item_id)
    video = MediaItem.find(media_item_id)
    return unless video

    # No row lock: holding one would pin a DB connection and block other writes
    # to this item for the whole download. Duplicate downloads are prevented by
    # the videos queue running one job at a time in a single Puma process; with
    # WEB_CONCURRENCY > 1, two processes could share the same staging dir.
    video.cache_video

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
