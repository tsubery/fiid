ActiveAdmin.register Feed do
  permit_params(*(Feed.attribute_names(&:to_sym) rescue []), library_ids: [])

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
    f.input :fetch_error_message
    f.input :last_sync
    f.input :last_sync
    f.input :libraries, :as => :select, :input_html => { :multiple => true }
    f.input :type, as: :select, collection: Feed.descendants.map { |c| [c.name, c.name] }
    f.actions
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
