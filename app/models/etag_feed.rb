class EtagFeed < Feed
  before_validation :fill_missing_details

  include Html

  ETAG_IGNORED_PATTERSN =  [
    # Some pages fight spam with random encoding of addresses
    /a href="mailto.*/,
    # some pages use timestamp to prevent caching of css
    /href="[^"]+" type=.text\/css./,
    # No need for scripts that can have random params
    /createElement\('script'\).*/
  ]

  def fill_missing_details
    return if title.present?

    self.title = get_title || ''
    self.description = get_description || ''
    self.etag = get_etag || ''
  end

  def recent_media_items(*)
    unless [200, 304].include?(html_response.code)
      return network_error_message(html_response)
    end

    body = ETAG_IGNORED_PATTERSN.reduce(html_response.body) do |str, pattern|
      str.gsub(pattern, "")
    end

    new_checksum = get_etag.presence || Digest::MD5.hexdigest(body)
    if html_response.code == 304 || new_checksum == etag
      []
    else
      update!(
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
        title: [title, Date.today.to_s].compact.join(" - "),
        url: url
      )]
    end
  rescue => e
    "Error fetching feed ##{id}: #{e.inspect}"
  end
end
