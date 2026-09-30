# frozen_string_literal: true

require "rails_helper"

module SMTPServer

  describe Client do
    let(:ip_address) { "1.2.3.4" }
    subject(:client) { described_class.new(ip_address) }

    describe "RCPT TO" do
      let(:helo) { "test.example.com" }
      let(:mail_from) { "test@example.com" }

      before do
        client.handle("HELO #{helo}")
        client.handle("MAIL FROM: #{mail_from}") if mail_from
      end

      context "when MAIL FROM has not been sent" do
        let(:mail_from) { nil }

        it "returns an error if RCPT TO is sent before MAIL FROM" do
          expect(client.handle("RCPT TO: no-route-here@internal.com")).to eq "503 EHLO/HELO and MAIL FROM first please"
          expect(client.state).to eq :welcomed
        end
      end

      it "returns an error if RCPT TO is not valid" do
        expect(client.handle("RCPT TO: blah")).to eq "501 Invalid RCPT TO"
      end

      it "returns an error if RCPT TO is empty" do
        expect(client.handle("RCPT TO: ")).to eq "501 RCPT TO should not be empty"
      end

      context "when the RCPT TO address is the system return path host" do
        it "returns an error if the server does not exist" do
          expect(client.handle("RCPT TO: nothing@#{Postal::Config.dns.return_path_domain}")).to eq "550 Invalid server token"
        end

        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          expect(client.handle("RCPT TO: #{server.token}@#{Postal::Config.dns.return_path_domain}"))
            .to eq "535 Mail server has been suspended"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          address = "#{server.token}@#{Postal::Config.dns.return_path_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:bounce, address, server]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when the RCPT TO address is on a host using the return path prefix" do
        it "returns an error if the server does not exist" do
          address = "nothing@#{Postal::Config.dns.custom_return_path_prefix}.example.com"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Invalid server token"
        end

        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          address = "#{server.token}@#{Postal::Config.dns.custom_return_path_prefix}.example.com"
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          address = "#{server.token}@#{Postal::Config.dns.custom_return_path_prefix}.example.com"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:bounce, address, server]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when the RCPT TO address is within the route domain" do
        it "returns an error if the route token is invalid" do
          address = "nothing@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Invalid route token"
        end

        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          route = create(:route, server: server)
          address = "#{route.token}@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "returns an error if the route is set to Reject mail" do
          server = create(:server)
          route = create(:route, server: server, mode: "Reject")
          address = "#{route.token}@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Route does not accept incoming messages"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          route = create(:route, server: server)
          address = "#{route.token}+tag1@#{Postal::Config.dns.route_domain}"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:route, "#{route.name}+tag1@#{route.domain.name}", server, { route: route }]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when the RCPT TO address is an individual return path" do
        let(:server) { create(:server) }
        let(:domain) { create(:domain, owner: server) }
        let(:address) { "#{server.token}@#{domain.return_path_domain}" }

        it "accepts the stored name without requiring DNS verification" do
          expect(domain.return_path_status).to be_nil
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:bounce, address, server]]
        end

        it "matches DNS names case insensitively" do
          expect(client.handle("RCPT TO: #{server.token}@#{domain.return_path_domain.upcase}")).to eq "250 OK"
        end

        it "rejects a token from another server" do
          other_server = create(:server, organization: server.organization)
          expect(client.handle("RCPT TO: #{other_server.token}@#{domain.return_path_domain}")).to eq "550 Invalid return path for server"
          expect(client.recipients).to be_empty
        end

        it "rejects an unknown token" do
          expect(client.handle("RCPT TO: unknown@#{domain.return_path_domain}")).to eq "550 Invalid server token"
        end

        it "rejects a suspended server" do
          server.update!(suspended_at: Time.now)
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "does not recognize an arbitrary name sharing the random prefix" do
          label = domain.return_path_domain.split('.').first
          expect(client.handle("RCPT TO: #{server.token}@#{label}.unrelated.test")).to start_with("550")
          expect(client.recipients).to be_empty
        end

        it "supports organization-owned domains for that organization's servers" do
          organization_domain = create(:domain, owner: server.organization)
          expect(client.handle("RCPT TO: #{server.token}@#{organization_domain.return_path_domain}")).to eq "250 OK"
        end

        it "rejects organization-owned names for a different organization" do
          organization_domain = create(:domain)
          expect(client.handle("RCPT TO: #{server.token}@#{organization_domain.return_path_domain}")).to eq "550 Invalid return path for server"
        end

        it "passes a received bounce through the existing message matching pipeline" do
          original = MessageFactory.outgoing(server, domain: domain)
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          client.handle("DATA")
          client.handle("From: mailer-daemon@remote.test")
          client.handle("Subject: Delivery failed")
          client.handle("")
          client.handle("Original message headers:")
          client.handle("X-VS-MsgID: #{original.token}")
          client.handle("\r")
          expect(client.handle(".\r")).to eq "250 OK"

          queued = QueuedMessage.find_by!(server_id: server.id)
          returned = queued.message
          expect(returned.bounce).to be true
          expect(returned.rcpt_to_return_path?).to be true
          MessageDequeuer::IncomingMessageProcessor.new(queued, logger: TestLogger.new).process
          expect(returned.reload.bounce_for_id).to eq original.id
          expect(original.reload.status).to eq "Bounced"
        end
      end

      context "when authenticated and the RCPT TO address is provided" do
        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          credential = create(:credential, server: server, type: "SMTP")
          expect(client.handle("AUTH PLAIN #{credential.to_smtp_plain}")).to match(/235 Granted for /)
          expect(client.handle("RCPT TO: outgoing@example.com")).to eq "535 Mail server has been suspended"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          credential = create(:credential, server: server, type: "SMTP")
          expect(client.handle("AUTH PLAIN #{credential.to_smtp_plain}")).to match(/235 Granted for /)
          expect(client.handle("RCPT TO: outgoing@example.com")).to eq "250 OK"
          expect(client.recipients).to eq [[:credential, "outgoing@example.com", server]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when not authenticated and the RCPT TO address is a route" do
        it "returns an error if the server is suspended" do
          server = create(:server, :suspended)
          route = create(:route, server: server)
          address = "#{route.name}@#{route.domain.name}"
          expect(client.handle("RCPT TO: #{address}")).to eq "535 Mail server has been suspended"
        end

        it "returns an error if the route is set to Reject mail" do
          server = create(:server)
          route = create(:route, server: server, mode: "Reject")
          address = "#{route.name}@#{route.domain.name}"
          expect(client.handle("RCPT TO: #{address}")).to eq "550 Route does not accept incoming messages"
        end

        it "adds a recipient if all OK" do
          server = create(:server)
          route = create(:route, server: server)
          address = "#{route.name}@#{route.domain.name}"
          expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
          expect(client.recipients).to eq [[:route, address, server, { route: route }]]
          expect(client.state).to eq :rcpt_to_received
        end
      end

      context "when not authenticated and RCPT TO does not match a route" do
        it "returns an error" do
          expect(client.handle("RCPT TO: nothing@nothing.com")).to eq "530 Authentication required"
        end

        context "when the connecting IP has an credential" do
          it "adds a recipient" do
            server = create(:server)
            create(:credential, server: server, type: "SMTP-IP", key: "1.0.0.0/8")
            address = "test@example.com"
            expect(client.handle("RCPT TO: #{address}")).to eq "250 OK"
            expect(client.recipients).to eq [[:credential, address, server]]
            expect(client.state).to eq :rcpt_to_received
          end
        end
      end
    end
  end

end
