# frozen_string_literal: true

require "socksify"

module Net
  class SMTP

    attr_accessor :source_address
    attr_accessor :socks5_proxy

    def secure_socket?
      return false unless @socket

      @socket.io.is_a?(OpenSSL::SSL::SSLSocket)
    end

    #
    # We had an issue where a message was sent to a server and was greylisted. It returned
    # a Net::SMTPUnknownError error. We then tried to send another message on the same
    # connection after running `rset` the next message didn't raise any exceptions because
    # net/smtp returns a '200 dummy reply code' and doesn't raise any exceptions.
    #
    def rset
      @error_occurred = false
      getok("RSET")
    end

    def rset_errors
      @error_occurred = false
    end

    private

    def tcp_socket(address, port)
      if socks5_proxy
        # Use SOCKS5 proxy for connection via SOCKSConnectionPeerAddress
        # This creates a per-connection proxy without affecting global settings
        peer = TCPSocket::SOCKSConnectionPeerAddress.new(
          socks5_proxy[:host],
          socks5_proxy[:port],
          address,
          socks5_proxy[:username].presence,
          socks5_proxy[:password].presence
        )
        TCPSocket.new(peer, port)
      else
        # Original behavior: direct connection with optional source address
        TCPSocket.open(address, port, source_address)
      end
    end

    class Response

      def message
        @string
      end

    end

  end
end
