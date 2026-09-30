# frozen_string_literal: true

require "rails_helper"

describe DNSNameWords do
  it "ships thousands of unique lowercase words of 5 to 10 letters" do
    words = File.readlines(Rails.root.join("resource/dns_words.txt"), chomp: true)
    expect(words.size).to be >= 3000
    expect(words.uniq).to eq words
    expect(words).to all(match(/\A[a-z]{5,10}\z/))
  end

  it "selects distinct words and excludes the legacy prefix" do
    excluded = File.readlines(Rails.root.join("resource/dns_words.txt"), chomp: true).first(100)
    selected = described_class.sample(4, excluding: excluded)
    expect(selected.uniq.size).to eq 4
    expect(selected & excluded).to be_empty
  end
end
