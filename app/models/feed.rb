class Feed < ApplicationRecord
  has_and_belongs_to_many :libraries
  has_many :media_items
  before_validation :set_type
  before_validation :normalize_url
  before_validation :fill_missing_details

  USER_AGENT = "FeedBurner/1.0 (http://www.FeedBurner.com)" # Cloudflare protection sometimes blocks default user agent

  def fill_missing_details
    if self.class.name != type
      self.becomes(type.constantize).fill_missing_details
    end
  end

  def normalized_url
    # overriden elsewhere
    self.url
  end

  def normalize_url
    if normalized_url != self.url
      self.url = normalized_url
    end
  end

  def set_type
    url = self.url || ''
    return if EtagFeed.name == self.type

    self.type = YoutubePlaylistFeed.parse_id(url) && YoutubePlaylistFeed.name ||
                YoutubeChannelFeed.parse_id(url) && YoutubeChannelFeed.name ||
                url =~ %r{\Ahttps://getpocket.com} && PocketFeed.name ||
                url =~ URI::MailTo::EMAIL_REGEXP && IncomingEmailFeed.name ||
                RssFeed.name
  end

  def rss_response
    @rss_response ||= Typhoeus.get(
      rss_url,
      timeout: 5,
      headers: {
        "User-Agent" => USER_AGENT,
        "If-None-Match" => etag
      }
    )
  end

  def clear_rss_response
    @rss_response = nil
  end

  def rss_entries
    Feedjira.parse(rss_response.body).entries.map do |entry|
      entry_id = entry.respond_to?(:entry_id) && entry.entry_id
      guid = if entry_id&.is_a?(String)
               entry_id
             elsif entry_id&.respond_to?(:guid)
               # sometimes nested under entry_id
               guid = entry_id.guid
             else
               entry.url
             end
      entry.to_h.merge(guid: guid).symbolize_keys
    end
  end
end
