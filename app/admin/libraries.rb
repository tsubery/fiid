ActiveAdmin.register Library do
  permit_params Library.attribute_names(&:to_sym)

  preserve_default_filters!
  remove_filter :media_items
end
