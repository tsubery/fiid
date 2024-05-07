class RetrieveFeedsJob < ApplicationJob
  queue_as :default

  def perform(feed_ids)
    Feed.where(id: feed_ids).each do |feed|
      refresh_feed(feed)
    end
  end

  def refresh_feed(feed)
    start_time = Time.now
    if feed.last_sync.nil?
      item_count = feed.historical_item_count
    else
      item_count = Float::INFINITY
    end

    since = feed.last_sync && feed.last_sync - 1.hour
    recent_media_items = feed.recent_media_items(since: since)
    if recent_media_items.is_a?(String)
      logger.error recent_media_items
      feed.update!(fetch_error_message: recent_media_items)
    else
      recent_media_items.reject(&:persisted?).each do |new_media_item|
        if new_media_item.save
          if item_count > 0
            feed.libraries.each do |library|
              library.add_media_item(new_media_item)
            end
          end
          item_count -= 1
        else
          Rails.logger.error("Could not save media item #{new_media_item.errors.inspect}")
        end
      end
      feed.reload.update!(
        last_sync: start_time,
        fetch_error_message: ''
      )
    end
  rescue => e
    feed.update(fetch_error_message: e.inspect)
  end

  def self.enqueue_all(klass = RssFeed)
    ids = klass
          .where("last_sync IS NULL or last_sync < ?", 15.minutes.ago)
          .joins(:libraries)
          .select do |feed|
      # Youtube feeds are fetched on demand
      # Randomness spreads polling across time to avoid spikes in resources utilization
      !feed.is_a?(YoutubeFeed) &&
        (feed.last_sync.nil? || feed.last_sync < rand(15..30).minutes.ago)
    end.map(&:id)
    ids.present? && perform_later(ids.uniq)
  end
end
