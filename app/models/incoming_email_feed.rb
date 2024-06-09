class IncomingEmailFeed < Feed
  SPAM_EMAIL = ENV.fetch('SPAM_EMAIL')

  def self.target_feed(email)
    feed = IncomingEmailFeed.find_by(url: email)
    feed || Rails.logger.info("Unknonwn recipient #{email.inspect}, defaulting to spam feed")
    feed || IncomingEmailFeed.find_by!(url: SPAM_EMAIL)
  end

  # Emails are pushed through a webhook so no need to poll
  def self.poll?
    false
  end

  # Methods for compatibility, we don't actually fetch any records
  def historical_item_count
    0
  end

  def recent_media_items(*)
    []
  end

  def fill_missing_details
    self.title = url
  end

  def email
    url
  end

  def spam?
    email == SPAM_EMAIL
  end

  def associate_previous_media_items
    media_items << MediaItem.where(sent_to: email)
    media_items.each do |media_item|
      libraries.each do |library|
        library.add_media_item(media_item)
      end
    end
  end
end
