class YoutubeFeed < Feed
  before_validation :fill_missing_details

  include Feed::Html

  # Refreshed when a podcast is requested
  def self.poll?
    false
  end

  def fill_missing_details
    return if [title, description, thumbnail_url].all?(&:present?)

    self.title = get_title || ''
    self.description = get_description || ''
    self.thumbnail_url = get_thumbnail_url || ''
  end

  def historical_item_count
    Float::INFINITY
  end

  def youtube_id
    self.class.parse_id(url)
  end
end
