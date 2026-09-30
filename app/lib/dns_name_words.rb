# frozen_string_literal: true

class DNSNameWords

  def self.sample(count, excluding: [])
    @words ||= File.readlines(Rails.root.join("resource/dns_words.txt"), chomp: true).map(&:freeze).freeze
    (@words - excluding).sample(count, random: SecureRandom)
  end

end
