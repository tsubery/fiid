ActiveAdmin.register MediaItem do
  permit_params(*(MediaItem.attribute_names(&:to_sym) rescue []), library_ids: [])

  form do |f|
    f.actions
    f.input :feed
    f.input :url
    f.input :guid
    f.input :duration_seconds
    f.input :title
    f.input :description
    f.input :author
    f.input :published_at
    f.input :reachable
    f.input :mime_type
    f.input :libraries, :as => :select, :input_html => { :multiple => true }
    f.actions
  end
end
