class RssFeed < Feed
  before_validation :fill_missing_details

  def user_agent
    # Cloudflare protection sometimes blocks default user agent
    "FeedBurner/1.0 (http://www.FeedBurner.com)".freeze
  end

  def fill_missing_details
    return if title.present?

    self.title = get_title || ''
    self.description = get_description || ''
  end

  def rss_headers
    rss_response.headers.transform_keys(&:downcase)
  end

  def recent_media_items(since: nil, redirects_left: 5)
    if rss_response.code == 301 && redirects_left.positive?
      redirect_url = rss_headers.fetch("location")
      Rails.logger.info("Updating feed #{id} from url: #{url.inspect} to #{redirect_url.inspect} due to 301 redirection")
      clear_rss_response
      update!(url: redirect_url)
      return recent_media_items(since: since, redirects_left: (redirects_left - 1))
    end

    return [] if rss_response.code == 304

    if rss_response.code != 200
      return network_error_message(rss_response)
    end

    new_checksum =
      rss_response.headers.transform_keys(&:downcase)["etag"].presence ||
      Digest::MD5.hexdigest(rss_response.body)

    if new_checksum == etag
      []
    else
      update!(etag: new_checksum)

      content_type = rss_headers["content-type"]
      unless content_type&.match?(%r{(application|text)/(atom\+|rss\+)?xml})
        return "Error fetching feed ##{id}: content-type #{content_type}"
      end

      rss_entries.map do |rss_entry|
        media_items.find_by(guid: rss_entry[:guid]) ||
          media_items.find_by(url: rss_entry[:url]) ||
          media_items.new(
            author: rss_entry.fetch(:author, title),
            description: rss_entry.values_at(:description, :content, :summary).compact.first,
            guid: rss_entry[:guid] || rss_entry[:url],
            mime_type: "text/html",
            published_at: rss_entry[:published],
            thumbnail_url: rss_entry[:enclosure_url] || '',
            title: [title, rss_entry[:title]].compact.join(" - "),
            url: rss_entry[:url] || MediaItem.temporary_url
          ).tap do |mi|
            if mi.url.nil? || mi.html?
              mi.url = MediaItem.temporary_url
            end
          end
      end
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end

  def parsed_xml
    if rss_response&.code == 200
      Nokogiri::XML.parse(rss_response.body)
    end
  rescue => e
    Rails.logger.error(e.inspect)
    nil
  end

  def get_title
    parsed_xml&.at_css('title')&.text
  end

  def get_description
    parsed_xml&.at_css('description')&.text
  end

  def rss_url
    url
  end
end
