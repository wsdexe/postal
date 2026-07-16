# frozen_string_literal: true

require "rails_helper"

describe OutgoingMessagePrototype do
  let(:server) { create(:server) }
  it "should create a new message" do
    domain = create(:domain, owner: server)
    prototype = OutgoingMessagePrototype.new(server, "127.0.0.1", "TestSuite", {
      from: "test@#{domain.name}",
      to: "test@example.com",
      subject: "Test Message",
      plain_body: "A plain body!"
    })

    expect(prototype.valid?).to be true
    message = prototype.create_message("test@example.com")
    expect(message).to be_a Hash
    expect(message[:id]).to be_a Integer
    expect(message[:token]).to be_a String
  end

  it "uses the server's manual header without requiring a credential" do
    server.received_header = "from web-test-gateway by VS with HTTP"
    domain = create(:domain, owner: server)
    prototype = described_class.new(server, "127.0.0.1", "web-ui", {
      from: "test@#{domain.name}",
      to: "test@example.com",
      subject: "Test Message",
      plain_body: "A plain body!"
    })

    expect(Mail.new(prototype.raw_message).header["Received"].decoded).to match(
      /\Afrom web-test-gateway by VS with HTTP; /
    )
  end
end
