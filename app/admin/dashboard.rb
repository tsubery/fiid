# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    library_meta = Library.pluck(:id, :type, :title).to_h do |id, type, title|
      icon = type == "ReadingLibrary" ? "📖" : "📻"
      [id, [icon, title]]
    end

    fetch_memberships = ->(items) {
      Library.joins(:media_items).where(media_items: { id: items.map(&:id) })
        .pluck("media_items.id", "libraries.id")
        .each_with_object({}) { |(item_id, lib_id), h| (h[item_id] ||= []) << lib_id }
    }

    div class: "blank_slate_container", id: "latest_media_items" do
      span class: "blank_slate" do
        h2 "Latest Videos & Audio"
        table do
          thead do
            th :id
            th :created_at
            th :published_at
            th :title
            th :feed
          end
          av_items = MediaItem.select(:id, :title, :url, :feed_id, :mime_type, :published_at, :created_at).includes(:feed).where(mime_type: [MediaItem::VIDEO_MIME_TYPE, MediaItem::AUDIO_MIME_TYPE]).order(created_at: :desc).first(params[:count]&.to_i || 10)
          av_memberships = fetch_memberships.call(av_items)
          av_items.each do |media_item|
            is_video = media_item.mime_type == MediaItem::VIDEO_MIME_TYPE
            tr do
              td style: "white-space: nowrap;" do
                span(is_video ? "🎬" : "🎧", title: is_video ? "Video" : "Audio")
                span " "
                lib_ids = av_memberships[media_item.id] || []
                if lib_ids.empty?
                  span "⚠️", title: "No libraries"
                else
                  lib_ids.each do |lib_id|
                    icon, lib_title = library_meta[lib_id]
                    span icon, title: lib_title
                  end
                end
                span " "
                a media_item.id, href: admin_media_item_path(media_item.id)
              end
              td time_ago_in_words(media_item.created_at)
              td(media_item.published_at ? time_ago_in_words(media_item.published_at) : "—")
              td do
                a media_item.title, href: media_item.url
              end
              td do
                a media_item.feed.title, href: admin_feed_path(media_item.feed_id)
              end
            end
          end
        end
      end
    end

    div class: "blank_slate_container", id: "latest_text" do

      span class: "blank_slate" do
        h2 "Latest Text"
        table do
          thead do
            th :id
            th :created_at
            th :published_at
            th :title
            th :sent_to
            th :feed
          end
          text_items = MediaItem.select(:id, :title, :url, :feed_id, :sent_to, :published_at, :created_at).includes(:feed).where(mime_type: MediaItem::HTML_MIME_TYPE).order(created_at: :desc).first(params[:count]&.to_i || 10)
          text_memberships = fetch_memberships.call(text_items)
          text_items.each do |media_item|
            icon, kind =
              if media_item.sent_to.present?
                ["✉️", "Email"]
              elsif media_item.feed.is_a?(WebScrapeFeed)
                ["🌐", "Web Scrape"]
              elsif media_item.feed.is_a?(RssFeed)
                ["📡", "RSS"]
              else
                ["📄", media_item.feed&.type.to_s.sub(/Feed\z/, "").presence || "Article"]
              end
            tr do
              td style: "white-space: nowrap;" do
                span icon, title: kind
                span " "
                lib_ids = text_memberships[media_item.id] || []
                if lib_ids.empty?
                  span "⚠️", title: "No libraries"
                else
                  lib_ids.each do |lib_id|
                    icon, lib_title = library_meta[lib_id]
                    span icon, title: lib_title
                  end
                end
                span " "
                a media_item.id, href: admin_media_item_path(media_item.id)
              end
              td time_ago_in_words(media_item.created_at)
              td(media_item.published_at ? time_ago_in_words(media_item.published_at) : "—")
              td do
                a media_item.title, href: media_item.url
              end
              td media_item.sent_to
              td do
                if media_item.feed&.respond_to?(:spam?) && media_item.feed.spam?
                  form_with(model: [:admin, Feed.new]) do |f|
                    f.hidden_field(:url, value: media_item.sent_to) +
                      f.hidden_field('library_ids', multiple: true, value: ReadingLibrary.pluck(:id)) +
                      f.submit
                  end
                else
                  a media_item.feed.title, href: admin_feed_path(media_item.feed_id)
                end
              end
            end
          end
        end
      end
    end
    div class: "blank_slate_container", id: "latest_feed_errors" do
      span class: "blank_slate" do
        h2 "Latest Errors"
        table do
          thead do
            th :id
            th :title
            th :updated_at
            th :last_sync
            th :fetch_error_message
            th :fix
          end
          Feed.where.not(fetch_error_message: "").find_each do |feed|
            tr do
              td do
                a feed.id, href: admin_feed_path(feed)
              end
              td do
                a feed.title, href: admin_feed_path(feed)
              end
              td time_ago_in_words(feed.updated_at)
              td feed.last_sync ? time_ago_in_words(feed.last_sync) : 'never'
              td feed.fetch_error_message
              td do
                a "refresh now", href: refresh_admin_feed_path(feed.id)
              end
            end
          end
        end
      end
    end
    script do
      'function refreshPage() { window.location.reload(); }; setInterval(refreshPage, 60*60*1000);'
    end
  end
end
