class MediaItem < ApplicationRecord
  validates :guid, uniqueness: { scope: :feed_id }
  validates :url, url: { schemes: %w[http https] }
  validates :url, format: /\A[^']+\z/

  belongs_to :feed
  has_and_belongs_to_many :libraries

  before_validation :fill_missing_details
  after_save :replace_temporary_url
  before_save :embed_images_and_resolve_links

  TEMPORARY_URL = "https://temporary.local"

  def self.temporary_url
    [TEMPORARY_URL, SecureRandom.hex].join('/') # Must be unique
  end

  def replace_temporary_url
    return unless url.starts_with?(TEMPORARY_URL)

    self.update!(url: article_url)
  end

  def article_url
    Rails.application.routes.url_helpers.media_item_article_url(self)
  end

  def fill_missing_details
    guid.nil? && self.guid = url
    return if [author, title, description, thumbnail_url, published_at, duration_seconds].all?(&:present?)

    if %r{\Ahttps://www\.youtube\.com} =~ url || %r{\Ahttps://youtu\.be/} =~ url
      info = Youtube::Video.new(url).get_information
      if info.present?
        youtube_id = info["id"]
        if youtube_id
          video = Youtube::Video.from_id(youtube_id)
          self.guid = video.guid
          self.url =  video.url
        else
          self.reachable = false
        end
        self.author = info["uploader"] || ''
        self.title = [feed.title, info["title"]].select(&:present?).join(" - ")
        self.published_at = info["upload_date"] && Date.parse(info["upload_date"])
        self.description = "Original Video: #{url}\nPublished At: #{published_at}\n #{info["description"]}"
        self.duration_seconds = info["duration"]
        self.thumbnail_url = info["thumbnails"]&.last&.fetch("url", "") || ''
      end
    end
  end

  def html?
    description && description =~ %r{\A[^<]*<(!DOCTYPE )?html}mi
  end

  def embed_images_and_resolve_links
    return unless html?

    doc = Nokogiri::HTML(description)

    embedded_images = 0
    resolved_links = 0

    doc.css('img').each do |image|
      image_url = image['src']
      next unless image_url =~ %r{\Ahttps?://}

      resp = Typhoeus.get(image_url, timeout: 5)
      content_type = resp.headers.transform_keys(&:downcase)["content-type"]
      if content_type && resp.code == 200
        image['original_src'] = image_url
        image['src'] = "data:image/#{content_type};base64, #{Base64.encode64(resp.body)}"
        embedded_images += 1
      end
    end

    doc.css('a').each do |link|
      link_url = link['href']
      uri = URI.parse(link_url) rescue nil
      next unless uri
      next unless uri.host == "substack.com" && uri.path =~ %r{\A/redirect/}

      uri.query = '' # Avoid tracking parameters

      resp = Typhoeus.head(uri.to_s, timeout: 5)
      redirect_url = resp.headers.transform_keys(&:downcase)["location"]
      if redirect_url && redirect_url != link_url
        link['original_href'] = link_url
        link['href'] = redirect_url
        resolved_links += 1
      end
    end

    if (embedded_images + resolved_links) > 0
      self.description = doc.to_html
    end
  end
end
