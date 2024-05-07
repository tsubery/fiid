class IncomingEmailFeed < Feed
  SPAM_EMAIL = ENV.fetch('SPAM_EMAIL')

  def self.target_feed(email)
    feed = IncomingEmailFeed.find_by(url: email)
    feed || Rails.logger.error("Unknonwn recipient #{email.inspect}, defaulting to spam feed")
    feed || feed = IncomingEmailFeed.find_by!(url: SPAM_EMAIL)
  end

  # Methods for compatibility, we don't actually fetch any records
  def historical_item_count
    0
  end

  def recent_media_items(since: nil)
    []
  end

  def fill_missing_details
    self.title = url
  end
end
