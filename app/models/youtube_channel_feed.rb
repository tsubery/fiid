class YoutubeChannelFeed < YoutubeFeed
  def normalized_url
    html_url
  end

  def html_url
    "https://www.youtube.com/channel/#{youtube_id}"
  end

  def rss_url
    "https://www.youtube.com/feeds/videos.xml?channel_id=#{youtube_id}"
  end

  def self.parse_id(url)
    %r{\Ahttps://(www\.)?youtube.com/channel/([^/]+)} =~ url && $2 ||
      %r{\Ahttps://(www\.)?youtube.com/feeds/videos.xml\?channel_id=([^&]+)} =~ url && $2
  end

  def recent_media_items(since: nil)
    unless [200, 304].include?(rss_response.code)
      return network_error_message(rss_response)
    end

    return [] if rss_response.code == 304

    new_checksum =
      rss_response.headers.transform_keys(&:downcase)["etag"].presence ||
      Digest::MD5.hexdigest(rss_response.body)
    if new_checksum == etag
      return []
    else
      self.update!(etag: new_checksum)

      rss_entries.map do |rss_entry|
        media_items.find_by(guid: rss_entry[:guid]) ||
          media_items.find_by(url: rss_entry[:url]) ||
          media_items.new(
            author: rss_entry[:author] || '',
            description: rss_entry[:content] || '',
            guid: rss_entry[:guid],
            mime_type: "video/mp4",
            published_at: rss_entry[:published],
            thumbnail_url: rss_entry[:media_thumbnail_url] || '',
            title: [title, rss_entry[:title]].compact.join(" - "),
            url: rss_entry.fetch(:url)
          )
      end
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end
end
