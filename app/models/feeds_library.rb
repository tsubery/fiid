class FeedsLibrary < ApplicationRecord
  belongs_to :feed
  belongs_to :library
end
