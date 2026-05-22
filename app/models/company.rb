class Company < ApplicationRecord
  has_one_attached :profile_picture

  has_many :users, dependent: :destroy
  has_many :chips, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :clients, dependent: :destroy
end
