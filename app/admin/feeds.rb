ActiveAdmin.register Feed do
  permit_params(*(Feed.attribute_names(&:to_sym) rescue []), :article_link_selector, :article_link_attribute, :podchaser_guest_name, library_ids: [])

  preserve_default_filters!
  remove_filter :media_items

  index do
    selectable_column
    id_column
    column :title
    column :url
    column :priority
    column :type
    column :last_sync
    actions
  end

  form do |f|
    f.actions
    f.input :url
    f.input :historical_item_count, default: 0
    f.input :priority, hint: "Lower number = higher priority (0 is highest)"
    f.input :title
    f.input :description
    f.input :thumbnail_url
    f.input :last_modified
    f.input :etag
    f.input :article_link_selector, label: "CSS Selector (WebScrapeFeed)", hint: "CSS selector for article elements on the page"
    f.input :article_link_attribute, label: "CSS Attribute (WebScrapeFeed)", hint: "CSS attribute for article elements on the page"
    f.input :podchaser_guest_name, label: "Guest Name (PodchaserGuestFeed)", hint: "Name of the podcast guest to track"
    f.input :fetch_error_message
    f.input :last_sync
    f.input :libraries, :as => :select, :input_html => { :multiple => true }
    f.input :type, as: :select, collection: Feed.descendants.map { |c| [c.name, c.name] }
    f.actions
  end

  action_item :refresh, only: :show do
    link_to "Refresh", refresh_admin_feed_path(resource)
  end

  member_action :refresh, method: :get do
    RetrieveFeedsJob.new.perform(resource.id)
    error_message = Feed.find(resource.id).fetch_error_message
    if error_message.blank?
      redirect_to admin_dashboard_path, notice: "Refreshed!"
    else
      redirect_to admin_dashboard_path, alert: error_message
    end
  end
end
