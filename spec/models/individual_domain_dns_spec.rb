# frozen_string_literal: true

require "rails_helper"

describe Domain, "individual DNS" do
  let(:domain) { create(:domain, name: "example.com") }
  let(:resolver) { instance_double(DNSResolver) }

  it "persists names once and keeps them on reload and ordinary updates" do
    names = domain.attributes.slice(*Domain::DNS_NAME_ATTRIBUTES)
    expect(names.values).to all(be_present)
    expect(domain.dns_spf_domain).to eq "spf.example.com"
    labels = [domain.dns_dkim_selector, domain.dns_return_path.split('.').first,
              domain.dns_return_path_target.split('.').first, domain.dns_verification_prefix]
    expect(labels).to all(match(/\A[a-z]{5,10}\z/))
    expect(labels.uniq.size).to eq 4
    domain.update!(outgoing: false)
    expect(domain.reload.attributes.slice(*Domain::DNS_NAME_ATTRIBUTES)).to eq names
  end

  it "does not change names when global DNS settings change" do
    expected = [domain.spf_record, domain.dkim_identifier, domain.return_path_domain, domain.return_path_target, domain.dns_verification_string]
    %i[spf_include dkim_identifier custom_return_path_prefix return_path_domain domain_verify_prefix].each do |setting|
      allow(Postal::Config.dns).to receive(setting).and_return("changed.example.net")
    end
    expect([domain.spf_record, domain.dkim_identifier, domain.return_path_domain, domain.return_path_target, domain.dns_verification_string]).to eq expected
  end

  it "leaves an existing domain on the original configuration after saving" do
    legacy = create(:domain, :legacy_dns)
    original_key = legacy.dkim_private_key
    legacy.update!(dns_checked_at: Time.now)
    legacy.reload
    expect(legacy.individual_dns?).to be false
    expect(legacy.attributes.slice(*Domain::DNS_NAME_ATTRIBUTES).values).to all(be_nil)
    expect(legacy.dkim_private_key).to eq original_key
    expect(legacy.spf_record).to eq "v=spf1 a mx include:#{Postal::Config.dns.spf_include} ~all"
    expect(legacy.dkim_identifier).to eq "#{Postal::Config.dns.dkim_identifier}-#{legacy.dkim_identifier_string}"
    expect(legacy.return_path_domain).to eq "#{Postal::Config.dns.custom_return_path_prefix}.#{legacy.name}"
    expect(legacy.return_path_target).to eq Postal::Config.dns.return_path_domain
    expect(legacy.dns_verification_string).to eq "#{Postal::Config.dns.domain_verify_prefix} #{legacy.verification_token}"
  end

  context "when checking DNS" do
    before do
      allow(domain).to receive(:resolver).and_return(resolver)
      allow(resolver).to receive(:txt).with(domain.name).and_return([domain.spf_record])
      allow(resolver).to receive(:txt).with(domain.spf_include).and_return(["v=spf1 ip4:192.0.2.10 ~all"])
      allow(resolver).to receive(:txt).with("#{domain.dkim_record_name}.#{domain.name}").and_return([domain.dkim_record])
      allow(resolver).to receive(:cname).with(domain.return_path_domain).and_return([domain.return_path_target])
      allow(resolver).to receive(:a).with(domain.return_path_target).and_return(["192.0.2.10"])
      allow(resolver).to receive(:aaaa).with(domain.return_path_target).and_return([])
      allow(resolver).to receive(:mx).with(domain.return_path_target).and_return([[10, domain.return_path_target]])
      allow(resolver).to receive(:txt).with(domain.return_path_target).and_return([domain.spf_record])
    end

    it "checks its complete DNS chain without querying the main domain's MX" do
      names = domain.attributes.slice(*Domain::DNS_NAME_ATTRIBUTES)
      expect(resolver).not_to receive(:mx).with(domain.name)
      expect(domain.check_dns).to be true
      expect(domain.reload.attributes.slice(*Domain::DNS_NAME_ATTRIBUTES)).to eq names
    end

    it "does not accept a missing SPF policy behind the include" do
      allow(resolver).to receive(:txt).with(domain.spf_include).and_return([])
      expect(domain.check_dns).to be false
      expect(domain.spf_status).to eq "Invalid"
    end

    it "does not accept a different hostname with the same SPF prefix" do
      allow(resolver).to receive(:txt).with(domain.name).and_return(["v=spf1 include:#{domain.spf_include}.other.test ~all"])
      expect(domain.check_dns).to be false
      expect(domain.spf_status).to eq "Invalid"
    end

    it "warns on duplicate SPF records" do
      allow(resolver).to receive(:txt).with(domain.name).and_return([domain.spf_record, "v=spf1 ~all"])
      expect(domain.check_dns).to be false
    end

    it "does not accept a CNAME pointing to the old shared host" do
      allow(resolver).to receive(:cname).with(domain.return_path_domain).and_return([Postal::Config.dns.return_path_domain])
      expect(domain.check_dns).to be false
      expect(domain.return_path_status).to eq "Invalid"
    end

    it "warns if the CNAME target has no address" do
      allow(resolver).to receive(:a).with(domain.return_path_target).and_return([])
      expect(domain.check_dns).to be false
      expect(domain.return_path_status).to eq "Invalid"
    end

    it "accepts SMTP's implicit MX when the target has an address" do
      allow(resolver).to receive(:mx).with(domain.return_path_target).and_return([])
      expect(domain.check_dns).to be true
    end

    it "warns if the target's MX points to a different mail service" do
      allow(resolver).to receive(:mx).with(domain.return_path_target).and_return([[10, "mail.other.test"]])
      expect(domain.check_dns).to be false
    end

    it "warns if SPF is missing on the return path target" do
      allow(resolver).to receive(:txt).with(domain.return_path_target).and_return([])
      expect(domain.check_dns).to be false
    end
  end
end
