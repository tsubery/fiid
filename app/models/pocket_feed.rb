class PocketFeed < Feed
  POCKET_URL = "https://getpocket.com".freeze

  def normalized_url
    POCKET_URL
  end

  def recent_media_items(since: 0)
    []
  end
end
