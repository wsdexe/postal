# frozen_string_literal: true

module Worker
  module Jobs
    class ProcessQueuedMessagesJob < BaseJob

      def call
        @lock_time = Time.current
        @locker = Postal.locker_name_with_suffix(SecureRandom.hex(8))

        find_ip_addresses
        lock_message_for_processing
        obtain_locked_messages
        process_messages
        @messages_to_process
      end

      private

      # Returns an array of IP address IDs that are present on the host that is
      # running this job, plus all proxy IP addresses (which can be processed by any worker).
      #
      # @return [Array<Integer>]
      def find_ip_addresses
        # Find local IP addresses on this host
        local_ips = { 4 => [], 6 => [] }
        Socket.ip_address_list.each do |address|
          next if local_ip?(address.ip_address)

          local_ips[address.ipv4? ? 4 : 6] << address.ip_address
        end

        # Get local pool IP addresses that match this host's IPs
        local_ip_address_ids = IPAddress.joins(:ip_pool)
                                        .where(ip_pools: { pool_type: "local" })
                                        .where(ipv4: local_ips[4])
                                        .or(IPAddress.joins(:ip_pool)
                                                     .where(ip_pools: { pool_type: "local" })
                                                     .where(ipv6: local_ips[6]))
                                        .pluck(:id)

        # Get ALL proxy pool IP addresses (any worker can process proxy messages)
        proxy_ip_address_ids = IPAddress.joins(:ip_pool)
                                        .where(ip_pools: { pool_type: "proxy" })
                                        .pluck(:id)

        @ip_addresses = local_ip_address_ids + proxy_ip_address_ids
      end

      # Is the given IP address a local address?
      #
      # @param [String] ip
      # @return [Boolean]
      def local_ip?(ip)
        !!(ip =~ /\A(127\.|fe80:|::)/)
      end

      # Obtain a queued message from the database for processing
      #
      # @return [void]
      def lock_message_for_processing
        QueuedMessage.where(ip_address_id: [nil, @ip_addresses])
                     .where(locked_by: nil, locked_at: nil)
                     .ready_with_delayed_retry
                     .limit(1)
                     .update_all(locked_by: @locker, locked_at: @lock_time)
      end

      # Get a full list of all messages which we can process (i.e. those which have just
      # been locked by us for processing)
      #
      # @return [void]
      def obtain_locked_messages
        @messages_to_process = QueuedMessage.where(locked_by: @locker, locked_at: @lock_time)
      end

      # Process the messages we obtained from the database
      #
      # @return [void]
      def process_messages
        @messages_to_process.each do |message|
          work_completed!
          MessageDequeuer.process(message, logger: logger)
        end
      end

    end
  end
end
