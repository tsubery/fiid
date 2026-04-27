class WebScrapeFeed < Feed
  include Html

  before_validation :fill_missing_details
  validates :article_link_selector, presence: true

  def fill_missing_details
    return if title.present?

    self.title = get_title || ''
    self.description = get_description || ''
    self.thumbnail_url = get_thumbnail_url || ''
  end

  def recent_media_items(*)
    return [] if html_response.code == 304

    unless html_response.code == 200
      return network_error_message(html_response)
    end

    new_checksum =
      html_headers["etag"].presence ||
      Digest::MD5.hexdigest(html_response.body)

    if new_checksum == etag
      []
    else
      update!(etag: new_checksum)
      extract_media_items(html)
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end

  private

  def extract_media_items(doc)
    links = doc.css(article_link_selector)

    if links.empty?
      Rollbar.error(
        "WebScrapeFeed##{id}: selector matched 0 items",
        feed_id: id,
        url: url,
        selector: article_link_selector
      )
      return []
    end

    base_uri = URI.parse(url)

    links.filter_map do |link|
      href = link[article_link_attribute.presence || "href"]
      next unless href

      article_url = URI.join(base_uri, href).to_s rescue next
      link_title = link.text.strip.presence || link.css("img")&.first&.[]("alt")

      media_items.find_by(guid: article_url) ||
        media_items.find_by(url: article_url) ||
        media_items.new(
          guid: article_url,
          url: article_url,
          title: [title, link_title].select(&:present?).join(" - "),
          author: title,
          description: '',
          mime_type: MediaItem::HTML_MIME_TYPE,
          published_at: Time.current,
          thumbnail_url: ''
        )
    end
  end
end
