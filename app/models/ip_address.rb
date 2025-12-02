# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_addresses
#
#  id                 :integer          not null, primary key
#  ip_pool_id         :integer
#  ipv4               :string(255)
#  ipv6               :string(255)
#  created_at         :datetime
#  updated_at         :datetime
#  hostname           :string(255)
#  priority           :integer
#  proxy_port         :integer          default(1080)
#  proxy_username     :string(255)
#  proxy_password     :string(255)
#  verified_at        :datetime
#  verification_error :string(255)
#

class IPAddress < ApplicationRecord

  belongs_to :ip_pool

  validates :ipv4, presence: true, uniqueness: { scope: :ip_pool_id }
  validates :hostname, presence: true
  validates :ipv6, uniqueness: { allow_blank: true }, unless: -> { ip_pool&.proxy? }
  validates :priority, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, only_integer: true }
  validates :proxy_port, numericality: {
    greater_than: 0,
    less_than_or_equal_to: 65_535,
    only_integer: true
  }, if: -> { ip_pool&.proxy? }

  scope :order_by_priority, -> { order(priority: :desc) }

  before_validation :set_default_priority
  before_validation :set_default_proxy_port, if: -> { ip_pool&.proxy? }
  before_validation :clear_ipv6_for_proxy, if: -> { ip_pool&.proxy? }

  def proxy_address
    return nil unless ip_pool&.proxy?

    "#{ipv4}:#{proxy_port}"
  end

  def verify_proxy!
    return false unless ip_pool&.proxy?

    require "net/http"
    require "socksify/http"

    begin
      uri = URI.parse("http://ifconfig.me/")

      proxy_class = if proxy_username.present? && proxy_password.present?
                      Net::HTTP.SOCKSProxy(ipv4, proxy_port, proxy_username, proxy_password)
                    else
                      Net::HTTP.SOCKSProxy(ipv4, proxy_port)
                    end

      proxy_class.start(uri.host, uri.port) do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        response = http.get("/")
        if response.is_a?(Net::HTTPSuccess)
          update!(verified_at: Time.current, verification_error: nil)
          return true
        else
          update!(verified_at: nil, verification_error: "HTTP #{response.code}")
          return false
        end
      end
    rescue StandardError => e
      update!(verified_at: nil, verification_error: e.message.truncate(255))
      false
    end
  end

  def verified?
    verified_at.present? && verification_error.nil?
  end

  def verification_status
    return nil unless ip_pool&.proxy?

    if verified?
      :verified
    elsif verification_error.present?
      :failed
    else
      :unverified
    end
  end

  private

  def set_default_priority
    return if priority.present?

    self.priority = 100
  end

  def set_default_proxy_port
    return if proxy_port.present?

    self.proxy_port = 1080
  end

  def clear_ipv6_for_proxy
    self.ipv6 = nil
  end

  class << self

    def select_by_priority
      order(Arel.sql("RAND() * priority DESC")).first
    end

  end

end
