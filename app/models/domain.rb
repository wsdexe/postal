# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                     :integer          not null, primary key
#  server_id              :integer
#  uuid                   :string(255)
#  name                   :string(255)
#  verification_token     :string(255)
#  verification_method    :string(255)
#  verified_at            :datetime
#  dkim_private_key       :text(65535)
#  created_at             :datetime
#  updated_at             :datetime
#  dns_checked_at         :datetime
#  spf_status             :string(255)
#  spf_error              :string(255)
#  dkim_status            :string(255)
#  dkim_error             :string(255)
#  mx_status              :string(255)
#  mx_error               :string(255)
#  return_path_status     :string(255)
#  return_path_error      :string(255)
#  outgoing               :boolean          default(TRUE)
#  incoming               :boolean          default(TRUE)
#  owner_type             :string(255)
#  owner_id               :integer
#  dkim_identifier_string :string(255)
#  use_for_any            :boolean
#
# Indexes
#
#  index_domains_on_server_id  (server_id)
#  index_domains_on_uuid       (uuid)
#

require "resolv"

class Domain < ApplicationRecord

  include HasUUID

  include HasDNSChecks

  DNS_LABEL_REGEX = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
  RANDOM_WORDS_PATH = Rails.root.join("resource", "randomwords.txt")

  VERIFICATION_EMAIL_ALIASES = %w[webmaster postmaster admin administrator hostmaster].freeze
  VERIFICATION_METHODS = %w[DNS Email].freeze

  belongs_to :server, optional: true
  belongs_to :owner, optional: true, polymorphic: true
  has_many :routes, dependent: :destroy
  has_many :track_domains, dependent: :destroy

  validates :name, presence: true, format: { with: /\A[a-z0-9\-.]*\z/ }, uniqueness: { case_sensitive: false, scope: [:owner_type, :owner_id], message: "is already added" }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }

  before_validation :assign_dkim_identifier_string, on: :create
  before_create :generate_dkim_key

  scope :verified, -> { where.not(verified_at: nil) }

  before_save :update_verification_token_on_method_change

  def verified?
    verified_at.present?
  end

  def mark_as_verified
    return false if verified?

    self.verified_at = Time.now
    save!
  end

  def parent_domains
    parts = name.split(".")
    parts[0, parts.size - 1].each_with_index.map do |_, i|
      parts[i..].join(".")
    end
  end

  def generate_dkim_key
    self.dkim_private_key = OpenSSL::PKey::RSA.new(1024).to_s
  end

  def dkim_key
    return nil unless dkim_private_key

    @dkim_key ||= OpenSSL::PKey::RSA.new(dkim_private_key)
  end

  def to_param
    uuid
  end

  def verification_email_addresses
    parent_domains.map do |domain|
      VERIFICATION_EMAIL_ALIASES.map do |a|
        "#{a}@#{domain}"
      end
    end.flatten
  end

  def spf_record(server_context = nil)
    "v=spf1 #{spf_mechanisms(server_context).join(' ')} ~all"
  end

  def return_path_spf_record(server_context = nil)
    spf_record(server_context)
  end

  def return_path_mx_records
    Postal::Config.dns.mx_records
  end

  def dkim_record
    return if dkim_key.nil?

    public_key = dkim_key.public_key.to_s.gsub(/-+[A-Z ]+-+\n/, "").gsub(/\n/, "")
    "v=DKIM1; t=s; h=sha256; p=#{public_key};"
  end

  def dkim_identifier
    return nil unless dkim_identifier_string

    dkim_identifier_string.downcase
  end

  def dkim_record_name
    identifier = dkim_identifier
    return if identifier.nil?

    "#{identifier}._domainkey"
  end

  def return_path_domain
    "#{dkim_identifier}.#{name}"
  end

  # Returns a DNSResolver instance that can be used to perform DNS lookups needed for
  # the verification and DNS checking for this domain.
  #
  # @return [DNSResolver]
  def resolver
    return DNSResolver.local if Postal::Config.postal.use_local_ns_for_domain_verification?

    @resolver ||= DNSResolver.for_domain(name)
  end

  def dns_verification_string
    "#{Postal::Config.dns.domain_verify_prefix} #{verification_token}"
  end

  def verify_with_dns
    return false unless verification_method == "DNS"

    result = resolver.txt(name)

    if result.include?(dns_verification_string)
      self.verified_at = Time.now
      return save
    end

    false
  end

  class << self

    def random_dns_word
      random_dns_words.sample || raise(Postal::Error, "No DNS-safe words found in #{RANDOM_WORDS_PATH}")
    end

    def random_dns_words
      @random_dns_words ||= File.readlines(RANDOM_WORDS_PATH, chomp: true).filter_map do |word|
        word = word.strip.downcase
        word if word.match?(DNS_LABEL_REGEX)
      end.uniq
    end

    def return_path_domain?(domain_name)
      return false if domain_name.blank?

      normalized_domain = domain_name.to_s.downcase
      where("LOWER(CONCAT(dkim_identifier_string, '.', name)) = ?", normalized_domain).exists?
    end

  end

  private

  def assign_dkim_identifier_string
    self.dkim_identifier_string = self.class.random_dns_word if dkim_identifier_string.blank?
  end

  def spf_mechanisms(server_context = nil)
    mechanisms = spf_ip_mechanisms(server_context)
    mechanisms.presence || ["include:#{Postal::Config.dns.spf_include}"]
  end

  def spf_ip_mechanisms(server_context = nil)
    spf_ip_addresses(server_context).each_with_object([]) do |address, mechanisms|
      mechanisms << "ip4:#{address.ipv4}" if address.ipv4.present?
      mechanisms << "ip6:#{address.ipv6}" if address.ipv6.present?
    end.uniq
  end

  def spf_ip_addresses(server_context = nil)
    pools = spf_ip_pools(server_context)
    return [] if pools.empty?

    IPAddress.where(ip_pool_id: pools.map(&:id)).order(:id).to_a
  end

  def spf_ip_pools(server_context = nil)
    spf_scope = server_context || owner || server
    case spf_scope
    when Server
      server_spf_ip_pools(spf_scope)
    when Organization
      organization_spf_ip_pools(spf_scope)
    else
      []
    end.compact.uniq
  end

  def server_spf_ip_pools(server)
    pools = [server.ip_pool]
    pools += server.ip_pool_rules.includes(:ip_pool).map(&:ip_pool)
    pools += server.organization.ip_pool_rules.includes(:ip_pool).map(&:ip_pool)
    pools
  end

  def organization_spf_ip_pools(organization)
    organization.ip_pools.to_a +
      organization.servers.present.includes(:ip_pool).map(&:ip_pool) +
      organization.ip_pool_rules.includes(:ip_pool).map(&:ip_pool)
  end

  def update_verification_token_on_method_change
    return unless verification_method_changed?

    if verification_method == "DNS"
      self.verification_token = SecureRandom.alphanumeric(32)
    elsif verification_method == "Email"
      self.verification_token = rand(999_999).to_s.ljust(6, "0")
    else
      self.verification_token = nil
    end
  end

end
