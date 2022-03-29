module Datadog
  module Transport
    # Defines abstract response for transport operations
    module Response
      def payload
        nil
      end

      def ok?
        nil
      end

      def unsupported?
        nil
      end

      def not_found?
        nil
      end

      def client_error?
        nil
      end

      def server_error?
        nil
      end

      def internal_error?
   