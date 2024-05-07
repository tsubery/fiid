class EtagFeed < Feed
  before_validation :fill_missing_details

  include Html

  def fill_missing_details
    return if title.present?

    self.title = get_title || ''
    self.description = get_description || ''
    self.etag = get_etag || ''
  end

  def historical_item_count
    0
  end

  def recent_media_items(since: nil, redirects_left: 5)
    unless [200, 304].include?(html_response.code)
      return "Error fetching feed ##{id}: response code #{html_response.code}"
    end

    new_checksum = get_etag.presence || Digest::MD5.hexdigest(html_response.body)
    if html_response.code == 304 || new_checksum == etag
      []
    else
      self.update!(
        etag: new_checksum,
        last_modified: get_last_modified || ''
      )

      [media_items.new(
        author: title,
        description: description,
        guid: etag,
        mime_type: "text/html",
        published_at: get_last_modified,
        thumbnail_url: '',
        title: title,
        url: url
      )]
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end
end
