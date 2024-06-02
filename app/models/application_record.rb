class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Allows activeadmin to present all associations and attributes
  def self.ransackable_associations(*)
    @ransackable_associations ||= reflect_on_all_associations.map { |a| a.name.to_s }
  end

  def self.ransackable_attributes(*)
    @ransackable_attributes ||= column_names + _ransackers.keys + _ransack_aliases.keys + attribute_aliases.keys
  end
end
