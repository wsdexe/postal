# frozen_string_literal: true

require "rails_helper"

describe DKIMHeader do
  [nil, "Missing", "Invalid"].each do |status|
    it "signs with the individual domain when DNS status is #{status.inspect}" do
      domain = create(:domain, dkim_status: status)
      raw = "From: test@#{domain.name}\r\nTo: receiver@example.net\r\nSubject: Test\r\n\r\nHello\r\n"
      header = described_class.new(domain, raw).dkim_header
      expect(header).to include("d=#{domain.name};", "s=#{domain.dkim_identifier};")
      expect(header).not_to include("d=#{Postal::Config.dns.return_path_domain};")
    end
  end

  it "retains the shared signing fallback for an existing domain" do
    domain = create(:domain, :legacy_dns, dkim_status: "Missing")
    raw = "From: test@#{domain.name}\r\nSubject: Test\r\n\r\nHello\r\n"
    expect(described_class.new(domain, raw).dkim_header).to include("d=#{Postal::Config.dns.return_path_domain};")
  end

  examples = Rails.root.join("spec/examples/dkim_signing/*.msg")
  Dir[examples].each do |path|
    contents = File.read(path)
    frontmatter, email = contents.split(/^---\n/m, 2)
    frontmatter = YAML.safe_load(frontmatter)
    email.strip
    it "works with #{path.split('/').last}" do
      mocked_time = Time.at(frontmatter["time"].to_i)
      allow(Time).to receive(:now).and_return(mocked_time)

      domain = instance_double("Domain")
      allow(domain).to receive(:dkim_status).and_return("OK")
      allow(domain).to receive(:name).and_return(frontmatter["domain"])
      allow(domain).to receive(:dkim_key).and_return(OpenSSL::PKey::RSA.new(frontmatter["private_key"]))
      allow(domain).to receive(:dkim_identifier).and_return(frontmatter["dkim_identifier"])

      expectation = "DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed; " \
                    "d=#{frontmatter['domain']}; " \
                    "s=#{frontmatter['dkim_identifier']}; t=#{mocked_time.to_i}; " \
                    "bh=#{frontmatter['bh']}; " \
                    "h=#{frontmatter['headers']}; " \
                    "b=#{frontmatter['b']}"

      header = described_class.new(domain, email)

      expect(header.dkim_header).to eq expectation
    end
  end
end
