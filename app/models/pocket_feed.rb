class PocketFeed < Feed
  POCKET_URL = "https://getpocket.com".freeze

  def normalized_url
    POCKET_URL
  end

  def recent_media_items(since: 0)
    PocketClient.list_videos(since: since).map do |entry|
      url = entry["resolved_url"]
      guid = Youtube::Video.new(url).guid
      media_items.find_by(url: url) ||
        media_items.find_by(guid: guid) ||
        media_items.new(
          author: entry["authors"]&.first&.values&.first&.fetch("name", '') || '',
          description: entry["excerpt"],
          duration_seconds: entry["listen_duration_estimate"],
          guid: entry["resolved_url"],
          mime_type: MediaItem::VIDEO_MIME_TYPE,
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
