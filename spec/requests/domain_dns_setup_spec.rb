# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Domain DNS setup", type: :request do
  let(:user) { create(:user, admin: true) }
  let(:organization) { create(:organization, owner: user) }
  let(:server) { create(:server, organization: organization) }

  before do
    post "/login", params: { email_address: user.email_address, password: "passw0rd" }
    # Render the real setup page without the unrelated asset-dependent application layout.
    allow_any_instance_of(DomainsController).to receive(:_layout).and_return(false)
  end

  it "shows the complete individual DNS instructions and no shared DNS hostnames" do
    domain = create(:domain, owner: server)
    get setup_organization_server_domain_path(organization, server, domain)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(domain.spf_include, domain.dkim_record_name, domain.return_path_domain, domain.return_path_target)
    expect(response.body).to include("YOUR_SENDING_IP", "port 25", "priority", "DNS warnings do not stop sending")
    expect(response.body).not_to include(Postal::Config.dns.spf_include, Postal::Config.dns.return_path_domain)
    Postal::Config.dns.mx_records.each { |mx| expect(response.body).not_to include(mx) }
  end

  it "keeps the original setup instructions for an existing domain" do
    domain = create(:domain, :legacy_dns, owner: server)
    get setup_organization_server_domain_path(organization, server, domain)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(Postal::Config.dns.spf_include, Postal::Config.dns.return_path_domain)
    expect(response.body).to include(domain.dkim_record_name, domain.return_path_domain)
    Postal::Config.dns.mx_records.each { |mx| expect(response.body).to include(mx) }
    expect(response.body).not_to include("YOUR_SENDING_IP")
  end

  it "shows a warning for a missing individual return path on the domain list" do
    domain = create(:domain, owner: server, return_path_status: "Missing", return_path_error: "Missing CNAME")
    get organization_server_domains_path(organization, server)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('domainList__check--warning', domain.name, "Missing CNAME")
  end
end
