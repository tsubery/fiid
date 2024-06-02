class PocketFeed < Feed
  POCKET_URL = "https://getpocket.com".freeze

  def normalized_url
    POCKET_URL
  end

  def historical_item_count
    Float::INFINITY
  end

  def recent_media_items(since: 0)
    PocketClient.list_videos(since: since).map do |entry|
      media_items.find_by(url: entry["resolved_url"]) ||
        media_items.new(
          author: entry["authors"]&.first&.values&.first&.fetch("name", '') || '',
          description: entry["excerpt"],
          duration_seconds: entry["listen_duration_estimate"],
          guid: entry["resolved_url"],
          mime_type: "video/mp4",
          published_at: Time.zone.at(entry["time_added"].to_i),
          thumbnail_url: entry["top_image_url"] || '',
          title: entry["resolved_title"],
          url: entry["resolved_url"]
        )
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end
end
