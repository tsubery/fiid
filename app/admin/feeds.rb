ActiveAdmin.register Feed do
  permit_params(*Feed.attribute_names(&:to_sym), library_ids: [])

  preserve_default_filters!
  remove_filter :media_items

  form do |f|
    f.actions
    f.input :title
    f.input :url
    f.input :description
    f.input :thumbnail_url
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
