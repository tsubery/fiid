# frozen_string_literal: true

ActiveAdmin.register_page "Dashboard" do
  menu priority: 1, label: proc { I18n.t("active_admin.dashboard") }

  content title: proc { I18n.t("active_admin.dashboard") } do
    div class: "blank_slate_container", id: "latest_media_items" do
      span class: "blank_slate" do
        h2 "Latest Videos"
        table do
          thead do
            th :id
            th :created_at
            th :title
            th :feed
          end
          MediaItem.includes(:feed).where(mime_type: "video/mp4").order(created_at: :desc).first(params[:count]&.to_i || 10).each do |media_item|
            tr do
              td do
                a media_item.id, href: admin_media_item_path(media_item.id)
              end
              td time_ago_in_words(media_item.created_at)
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
    div class: "blank_slate_container", id: "latest_articles" do
      span class: "blank_slate" do
        h2 "Latest Articles"
        table do
          thead do
            th :id
            th :created_at
            th :title
            th :feed
          end
          MediaItem.includes(:feed).where.not(mime_type: "video/mp4").order(created_at: :desc).first(params[:count]&.to_i || 10).each do |media_item|
            tr do
              td do
                a media_item.id, href: admin_media_item_path(media_item.id)
              end
              td time_ago_in_words(media_item.created_at)
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
  end
end
