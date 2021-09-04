require_relative 'media_type'

module Datadog
  module AppSec
    module Utils
      module HTTP
        # Implementation of media range for content negotiation
        class MediaRange
          class ParseError < ::StandardError
          end

          WILDCARD = '*'.freeze
          WILDCARD_RE = ::Regexp.escape(WILDCARD)

          # See: https://www.rfc-editor.org/rfc/rfc7230#section-3.2.6
          TOKEN_RE = /[-#$%&'*+.^_`|~A-Za-z0-9]+/.freeze

          # See: https://www.rfc-editor.org/rfc/rfc7231#section-3.1.1.1
          PARAMETER_RE = %r{ # rubocop:disable Style/RegexpLiteral
            (?:
              (?<parameter_name>#{TOKEN_RE})
              =
              (?:
                (?<parameter_value>#{TOKEN_RE})
                |
                "(?<parameter_value>[^"]+)"
              )
            )
          }ix.freeze

          # See: https://www.rfc-editor.org/rfc/rfc7231#section-5.3.2
          ACCEPT_EXT_RE = %r{ # rubocop:disable Style/RegexpLiteral
            (?:
              (?<ext_name>#{TOKEN_RE})
              =
              (?:
                (?<ext_value>#{TOKEN_RE})
                |
                "(?<ext_value>[^"]+)"
             