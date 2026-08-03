class Feed < ApplicationRecord
  has_and_belongs_to_many :libraries
  has_many :media_items
  before_validation :set_type
  before_validation :normalize_url
  before_validation :fill_missing_details
  after_create :associate_previous_media_items
  after_create :refresh_later
  validates :historical_item_count, numericality: { greater_than_or_equal_to: 0 }
  validates :priority, numericality: { greater_than_or_equal_to: 0 }

  def user_agent
    # Cloudflare protection sometimes blocks default user agent
    "Mozilla/5.0 (X11; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/115.0".freeze
  end

  def request_headers
    {
      "User-Agent" => user_agent,
    }.merge(
      etag.present? ? { "If-None-Match" => etag } : {}
    )
  end

  def refresh_later
    RetrieveFeedsJob.perform_later(id)
  end

  def associate_previous_media_items
    if self.class.name != type
      becomes(type.constantize).associate_previous_media_items
    end
  end

  # Signifies it needs to be manually refreshed periodically
  def self.poll?
    true
  end

  def fill_missing_details
    if self.class.name != type
      becomes(type.constantize).fill_missing_details
    end
  end

  def normalized_url
    # overriden elsewhere
    url
  end

  def normalize_url
    if normalized_url != url
      self.url = normalized_url
    end
  end

  def set_type
    url = self.url || ''
    return if EtagFeed.name == type
    return if PersonalFeed.name == type

    self.type = YoutubePlaylistFeed.parse_id(url) && YoutubePlaylistFeed.name ||
                YoutubeChannelFeed.parse_id(url) && YoutubeChannelFeed.name ||
                url =~ URI::MailTo::EMAIL_REGEXP && IncomingEmailFeed.name ||
                RssFeed.name
  end

  def rss_response
    @rss_response ||= Typhoeus.get(
      rss_url,
      timeout: 5,
      headers: request_headers
    )
  end

  def clear_rss_response
    @rss_response = nil
  end

  def rss_entries
    Feedjira.parse(rss_response.body).entries.map do |entry|
      entry_id = entry.respond_to?(:entry_id) && entry.entry_id
      guid = if entry_id.is_a?(String)
               entry_id
             elsif entry_id.respond_to?(:guid)
               # sometimes nested under entry_id
               entry_id.guid
             else
               entry.url
             end
      entry.to_h.merge(guid: guid).symbolize_keys
    end
  end

  private

  def network_error_message(resp)
    "Error fetching feed ##{id}: response code #{resp.code}#{
      resp.return_message.present? ? ", message: #{resp.return_message}" : ''
    }"
  end
end
