class Passkey < ApplicationRecord
  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :label, presence: true
end
