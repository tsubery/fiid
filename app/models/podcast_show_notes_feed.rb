class PodcastShowNotesFeed < RssFeed
  ITUNES_NAMESPACE = { "itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd" }.freeze

  def fill_missing_details
    super
    if thumbnail_url.blank?
      self.thumbnail_url = get_thumbnail_url || ''
    end
  end

  def get_thumbnail_url
    parsed_xml&.at_xpath("/rss/channel/itunes:image", ITUNES_NAMESPACE)&.[]("href").presence ||
      parsed_xml&.at_xpath("/rss/channel/image/url")&.text.presence
  end

  # Rendered as a full HTML document so the reading list shows it inline,
  # like an incoming email, instead of framing the episode page.
  def build_media_item(rss_entry)
    media_items.new(
      author: rss_entry[:itunes_author].presence || title,
      description: render_show_notes(rss_entry),
      guid: rss_entry[:guid] || rss_entry[:url],
      mime_type: MediaItem::HTML_MIME_TYPE,
      published_at: rss_entry[:published],
      thumbnail_url: artwork_url(rss_entry),
      title: [title, rss_entry[:title]].compact.join(" - "),
      url: MediaItem.temporary_url
    )
  end

  def self.parse_duration(value)
    return if value.blank?

    # itunes:duration is either plain seconds or [HH:]MM:SS
    value.to_s.split(":").map(&:to_i).reduce(0) { |total, part| total * 60 + part }
  end

  def self.format_duration(seconds)
    return unless seconds&.positive?

    hours, minutes = (seconds / 60.0).round.divmod(60)
    hours.positive? ? "#{hours} h #{minutes} min" : "#{minutes} min"
  end

  private

  def artwork_url(rss_entry)
    rss_entry[:itunes_image].presence || thumbnail_url
  end

  def render_show_notes(rss_entry)
    ApplicationController.render(
      template: "media_items/show_notes",
      layout: false,
      locals: {
        podcast_title: title,
        episode_title: rss_entry[:title],
        episode_url: rss_entry[:url],
        audio_url: rss_entry[:enclosure_url],
        artwork_url: artwork_url(rss_entry),
        published_at: rss_entry[:published],
        duration: self.class.format_duration(self.class.parse_duration(rss_entry[:itunes_duration])),
        notes: rss_entry.values_at(:content, :summary, :itunes_summary).find(&:present?) || ''
      }
    )
  end
end
