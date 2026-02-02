ActiveAdmin.register MediaItem do
  permit_params(*(MediaItem.attribute_names(&:to_sym) rescue []), library_ids: [])

  scope :all, default: true
  scope :articles, -> { MediaItem.articles }
  scope :unarchived_articles, -> { MediaItem.articles.unarchived }

  index do
    selectable_column
    id_column
    column :title
    column :feed
    column :mime_type
    column :archived
    column :created_at
    actions
  end

  batch_action :archive do |ids|
    batch_action_collection.find(ids).each(&:archive!)
    redirect_to collection_path, notice: "Articles archived"
  end

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
    f.input :archived
    f.input :libraries, :as => :select, :input_html => { :multiple => true }
    f.actions
  end

  action_item :fetch_details, only: [:show, :edit] do
    link_to "Fetch Details", fetch_details_admin_media_item_path(resource)
  end

  member_action :fetch_details, method: :get do
    resource.update(updated_at: nil, reachable: nil)
    redirect_to admin_media_item_path, notice: "Fetched!"
  end
end
