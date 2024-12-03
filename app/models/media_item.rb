class MediaItem < ApplicationRecord
  validates :guid, uniqueness: { scope: :feed_id }
  validates :url, url: { schemes: %w[http https] }
  validates :url, format: /\A[^']+\z/
  validates :feed, presence: true

  belongs_to :feed
  has_and_belongs_to_many :libraries

  before_validation :fill_missing_details
  after_save :replace_temporary_url
  before_save :embed_images_and_resolve_links
  after_save :cache_article

  TEMPORARY_URL = "https://temporary.local".freeze
  VIDEO_MIME_TYPE = "video/mp4"
  AUDIO_MIME_TYPE = "audio/mp4"

  def self.temporary_url
    [TEMPORARY_URL, SecureRandom.hex].join('/') # Must be unique
  end

  def replace_temporary_url
    return unless url.starts_with?(TEMPORARY_URL)

    update!(url: article_url)
  end

  def article_url
    Rails.application.routes.url_helpers.media_item_article_url(self)
  end

  def has_all_details?
    [(reachable == true), title, description, duration_seconds].all?(&:present?)
  end

  def fill_missing_details
    return if has_all_details?
    return if reachable == false # nil means unknown

    # Tried in the last hour
    return if updated_at && updated_at != created_at && (Time.now - updated_at) < 1.hour

    # Exponential backoff
    return if updated_at && created_at && updated_at != created_at && Time.now < (created_at + (updated_at - created_at)*2)

    self.updated_at = Time.now
    if guid.nil?
      self.guid = url
    end

    if %r{\Ahttps://(www\.)?(youtube|vimeo)\.com/} =~ url || %r{\Ahttps://youtu\.be/} =~ url
      self.mime_type = VIDEO_MIME_TYPE
    end

    if mime_type == VIDEO_MIME_TYPE
      info = Youtube::Video.new(url).get_information

      if info.present?
        # Wait for stream to finish
        success = info["is_live"] ? nil : !!info["id"]

        if success && info['extractor'] == 'youtube'
          video = Youtube::Video.from_id(info["id"])
          self.guid = video.guid
          self.url =  video.url
        end

        if success || (created_at && created_at < 1.week.ago)
          self.reachable = success
          self.author = info["uploader"] || ''
          self.title = [feed&.title, info["title"]].select(&:present?).join(" - ")
          self.published_at = info["upload_date"] && Date.parse(info["upload_date"])
          self.description = "Original Video: #{url}\nPublished At: #{published_at}\n #{info["description"]}"
          self.duration_seconds = info["duration"] || 0
          self.thumbnail_url = info["thumbnails"]&.last&.fetch("url", "") || ''
        end
      end
      save!
    end
  end

  def html?
    description && description =~ /\A[^<]*<(!DOCTYPE )?html/mi
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
      next unless content_type && resp.code == 200

      image['original_src'] = image_url
      image['src'] = "data:image/#{content_type};base64, #{Base64.encode64(resp.body)}"
      embedded_images += 1
    end

    doc.css('a').each do |link|
      link_url = link['href']
      uri = URI.parse(link_url) rescue nil
      next unless uri
      next unless uri.host == "substack.com" && uri.path =~ %r{\A/redirect/}

      uri.query = '' # Avoid tracking parameters

      resp = Typhoeus.head(uri.to_s, timeout: 5)
      redirect_url = resp.headers.transform_keys(&:downcase)["location"]
      next unless redirect_url && redirect_url != link_url

      link['original_href'] = link_url
      link['href'] = redirect_url
      resolved_links += 1
    end

    if (embedded_images + resolved_links).positive?
      self.description = doc.to_html
    end
  end

  def cache_article
    return unless html?

    dir = "public/media_items/#{id}"
    FileUtils.mkdir_p(dir)
    html = ApplicationController.render(
      template: 'media_items/article',
      assigns: { media_item: self },
      layout: false
    )
    Zlib::GzipWriter.open("#{dir}/article.html.gz") do |gz|
      gz.write html
    end
  end
end
