# frozen_string_literal: true

require "rails_helper"

module MessageDequeuer

  RSpec.describe InitialProcessor do
    let(:server) { create(:server) }
    let(:logger) { TestLogger.new }
    let(:route) { create(:route, server: server) }
    let(:message) { MessageFactory.incoming(server, route: route) }
    let(:queued_message) { create(:queued_message, :locked, message: message) }

    subject(:processor) { described_class.new(queued_message, logger: logger) }

    it "has state when not given any" do
      expect(processor.state).to be_a State
    end

    context "when associated message does not exist" do
      let(:queued_message) { create(:queued_message, :locked, message_id: 12_345) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/unqueue because backend message has been removed/)
      end

      it "removes from queued message" do
        processor.process
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when the queued message is not ready for processing" do
      let(:queued_message) { create(:queued_message, :locked, message: message, retry_after: 1.hour.from_now) }

      it "logs" do
        processor.process
        expect(logger).to have_logged(/skipping because message isn't ready for processing/)
      end

      it "unlocks and keeps the queued message" do
        processor.process
        expect(queued_message.reload).to_not be_locked
      end
    end

    context "when there are no other batchable messages" do
      it "calls the single message processor for the initial message" do
        expect(SingleMessageProcessor).to receive(:process).with(queued_message,
                                                                 logger: logger,
                                                                 state: processor.state)
        processor.process
      end
    end

    context "when there are batchable messages" do
      before do
        @message2 = MessageFactory.incoming(server, route: route)
        @queued_message2 = create(:queued_message, message: @message2)
        @message3 = MessageFactory.incoming(server, route: route)
        @queued_message3 = create(:queued_message, message: @message3)
      end

      context "when postal.batch_queued_messages is enabled" do
        it "calls the single message process for the initial message and all batchable messages" do
          [queued_message, @queued_message2, @queued_message3].each do |msg|
            expect(SingleMessageProcessor).to receive(:process).with(msg,
                                                                     logger: logger,
                                                                     state: processor.state)
          end
          processor.process
        end
      end

      context "when postal.batch_queued_messages is disabled" do
        before do
          allow(Postal::Config.postal).to receive(:batch_queued_messages?) { false }
        end

        it "does not call the single message process more than once" do
          expect(SingleMessageProcessor).to receive(:process).once.with(queued_message,
                                                                        logger: logger,
                                                                        state: processor.state)
          processor.process
        end
      end
    end

    context "when an outgoing iCloud batch loses its SMTP connection" do
      let(:domain) { create(:domain, server: server) }
      let(:message) do
        MessageFactory.outgoing(server, domain: domain) do |outgoing_message|
          outgoing_message.rcpt_to = "first@icloud.com"
        end
      end
      let(:other_message) do
        MessageFactory.outgoing(server, domain: domain) do |outgoing_message|
          outgoing_message.rcpt_to = "second@icloud.com"
        end
      end
      let(:queued_message) { create(:queued_message, :locked, message: message) }
      let!(:other_queued_message) { create(:queued_message, message: other_message) }
      let(:connection_result) do
        SendResult.new do |result|
          result.type = "SoftFail"
          result.retry = true
          result.connect_error = true
          result.details = "iCloud closed the connection"
        end
      end
      let(:sent_result) do
        SendResult.new do |result|
          result.type = "Sent"
          result.details = "Accepted by iCloud"
        end
      end
      let(:first_sender) { instance_double(SMTPSender, start: nil, finish: nil) }
      let(:retry_sender) { instance_double(SMTPSender, start: nil, finish: nil) }

      it "requeues every message and later sends them through a new sender" do
        allow(SMTPSender).to receive(:new).with("icloud.com", nil).and_return(first_sender, retry_sender)
        expect(first_sender).to receive(:send_message).with(message).once.and_return(connection_result)

        started_at = Time.current
        Timecop.freeze(started_at) do
          processor.process
        end

        expect(queued_message.reload).to have_attributes(attempts: 1, locked_at: nil)
        expect(other_queued_message.reload).to have_attributes(attempts: 1, locked_at: nil)
        expect(queued_message.retry_after).to be_present
        expect(other_queued_message.retry_after).to be_present

        Timecop.freeze(started_at + 6.minutes) do
          queued_message.update!(locked_by: "retry-worker", locked_at: Time.current)
          retry_processor = described_class.new(queued_message, logger: logger)

          expect(retry_processor.state).not_to be processor.state
          expect(retry_sender).to receive(:send_message).with(message).once.and_return(sent_result)
          expect(retry_sender).to receive(:send_message).with(other_message).once.and_return(sent_result)
          retry_processor.process
        end

        expect(first_sender).to have_received(:start).once
        expect(retry_sender).to have_received(:start).once
        expect { queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { other_queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when iCloud and Mail.ru messages are processed independently" do
      let(:domain) { create(:domain, server: server) }
      let(:message) do
        MessageFactory.outgoing(server, domain: domain) do |outgoing_message|
          outgoing_message.rcpt_to = "first@icloud.com"
        end
      end
      let(:mail_message) do
        MessageFactory.outgoing(server, domain: domain) do |outgoing_message|
          outgoing_message.rcpt_to = "second@mail.ru"
        end
      end
      let(:queued_message) { create(:queued_message, :locked, message: message) }
      let!(:mail_queued_message) { create(:queued_message, :locked, message: mail_message) }
      let(:icloud_result) do
        SendResult.new do |result|
          result.type = "SoftFail"
          result.retry = true
          result.connect_error = true
          result.details = "iCloud returned 421"
        end
      end
      let(:mail_result) do
        SendResult.new do |result|
          result.type = "Sent"
          result.details = "Accepted by Mail.ru"
        end
      end
      let(:icloud_sender) { instance_double(SMTPSender, start: nil, finish: nil, send_message: icloud_result) }
      let(:mail_sender) { instance_double(SMTPSender, start: nil, finish: nil, send_message: mail_result) }

      it "does not leak the iCloud connection result into the Mail.ru state" do
        allow(SMTPSender).to receive(:new).with("icloud.com", nil).and_return(icloud_sender)
        allow(SMTPSender).to receive(:new).with("mail.ru", nil).and_return(mail_sender)
        mail_processor = described_class.new(mail_queued_message, logger: logger)

        processor.process

        expect(mail_sender).not_to have_received(:send_message)
        expect(queued_message.reload).to have_attributes(attempts: 1, locked_at: nil)
        expect(mail_queued_message.reload).to be_locked

        mail_processor.process

        expect(processor.state).not_to be mail_processor.state
        expect(icloud_sender).to have_received(:start).once
        expect(mail_sender).to have_received(:start).once
        expect(icloud_sender).to have_received(:send_message).once
        expect(mail_sender).to have_received(:send_message).once
        expect(queued_message.reload.retry_after).to be_present
        expect { mail_queued_message.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when an error occurs while finding batchable messages" do
      before do
        allow(queued_message).to receive(:batchable_messages) { 1 / 0 }
      end

      it "unlocks the queued message and raises the error" do
        expect { processor.process }.to raise_error(ZeroDivisionError)
        expect(queued_message.reload).to_not be_locked
      end
    end

    context "when finished" do
      it "notifies the state that processing is complete" do
        expect(processor.state).to receive(:finished)
        processor.process
      end
    end
  end

end
