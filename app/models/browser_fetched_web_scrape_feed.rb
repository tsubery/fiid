class BrowserFetchedWebScrapeFeed < WebScrapeFeed
  def self.poll?
    false
  end

  def fill_missing_details
  end

  def recent_media_items(*)
    []
  end

  def ingest_html(raw_html)
    doc = Nokogiri::HTML(raw_html)
    fill_details_from(doc) unless title.present?
    items = extract_media_items(doc)

    if items.is_a?(String)
      update!(fetch_error_message: items)
      return 0
    end

    count = 0
    items.reject(&:persisted?).each do |item|
      if item.save
        libraries.each { |lib| lib.add_media_item(item) }
        count += 1
      end
    end

    update!(last_sync: Time.current, fetch_error_message: '')
    count
  end

  private

  def fill_details_from(doc)
    self.title = doc.css("title").text.presence || ''
    self.description = doc.css("meta[name='description']")&.attribute("content")&.value || ''
    self.thumbnail_url = doc.css("meta[property='og:image']")&.attribute("content")&.value || ''
  end
end
