class Library < ApplicationRecord
  has_and_belongs_to_many :media_items
  has_and_belongs_to_many :feeds
  validates :episode_count, numericality: { greater_than_or_equal_to: 0 }

  def add_media_item(new_media_item)
    media_items << new_media_item
  end

  DEFAULT_LANGUAGE = 'en'.freeze
  DEFAULT_EPISODE_COUNT = 200

  def generate_podcast(current_url, audio_url:, video_url:)
    Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
      xml.rss(
        'version' => '2.0',
        'xmlns:itunes' => 'http://www.itunes.com/dtds/podcast-1.0.dtd',
        'xmlns:atom' => 'http://www.w3.org/2005/Atom',
        'xmlns:content' => 'http://purl.org/rss/1.0/modules/content/',
        'xmlns:googleplay' => 'https://www.google.com/schemas/play-podcasts/1.0/'
      ) do |rss_node|
        rss_node.channel do |channel|
          channel.link(current_url)
          channel.language(DEFAULT_LANGUAGE)
          channel.title(title)
          channel.description(description)
          channel.author(author)
          channel.image do |image|
            image.url(thumbnail_url)
            image.title(title)
            image.link(current_url)
          end

          channel['googleplay'].author(author)
          channel['googleplay'].image(href: thumbnail_url)

          channel['itunes'].author(author)
          channel['itunes'].owner(author)
          channel['itunes'].title(title)
          channel['itunes'].link(current_url)
          channel['itunes'].explicit('no')

          # id: asc allows stable sort for test with same timestamp
          media_items.order(updated_at: :desc, id: :asc).limit(episode_count).flat_map do |media_item|
            [
              [audio, audio_url.call(media_item.id), 'audio/mpeg'],
              [video, video_url.call(media_item.id), 'video/mpeg']
            ].select(&:first).map do |_enabled, media_item_link, mime_type|
              channel.item do |item|
                media_item.fill_missing_details
                next unless media_item.has_all_details?

                guid = media_item.url
                item.link(media_item_link)

                title = media_item.title

                item.title(title)

                item.description(media_item.description)
                item.guid(guid)
                item.pubDate(media_item.created_at&.rfc822)
                item.enclosure(url: media_item_link, type: mime_type, length: (media_item.duration_seconds || 100) * 1000) # arbitrary length
                item['itunes'].image(media_item.thumbnail_url)
                item['itunes'].duration(Time.at(media_item.duration_seconds || 0).utc.strftime("%H:%M:%S"))
                item['itunes'].title(title)
                item['itunes'].author(media_item.author)
              end
            end
          end
        end
      end
    end
  rescue => e
    Rails.logger.debug e.inspect
    Rails.logger.debug e.backtrace
    e
  end
end
