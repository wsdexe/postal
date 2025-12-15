# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_pools
#
#  id         :integer          not null, primary key
#  name       :string(255)
#  uuid       :string(255)
#  created_at :datetime
#  updated_at :datetime
#  default    :boolean          default(FALSE)
#  pool_type  :string(255)      default("local")
#
# Indexes
#
#  index_ip_pools_on_uuid       (uuid)
#  index_ip_pools_on_pool_type  (pool_type)
#

class IPPool < ApplicationRecord

  POOL_TYPES = %w[local proxy].freeze

  include HasUUID

  validates :name, presence: true
  validates :pool_type, inclusion: { in: POOL_TYPES }
  validate :proxy_cannot_be_default

  has_many :ip_addresses, dependent: :restrict_with_exception
  has_many :servers, dependent: :restrict_with_exception
  has_many :organization_ip_pools, dependent: :destroy
  has_many :organizations, through: :organization_ip_pools
  has_many :ip_pool_rules, dependent: :destroy

  scope :local_pools, -> { where(pool_type: "local") }
  scope :proxy_pools, -> { where(pool_type: "proxy") }

  def self.default
    where(default: true).order(:id).first
  end

  def local?
    pool_type == "local"
  end

  def proxy?
    pool_type == "proxy"
  end

  private

  def proxy_cannot_be_default
    return unless proxy? && default?

    errors.add(:default, "cannot be true for proxy pools")
  end

end
