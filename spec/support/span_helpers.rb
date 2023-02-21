
require 'datadog/tracing/metadata/ext'

module SpanHelpers
  RSpec::Matchers.define :have_error do
    match do |span|
      @actual = span.status
      values_match? Datadog::Tracing::Metadata::Ext::Errors::STATUS, @actual
    end

    def description_of(actual)
      "Span with status #{super}"
    end
  end

  def self.define_have_error_tag(tag_name, tag)
    RSpec::Matchers.define "have_error_#{tag_name}" do |*args|
      match do |span|
        expected = args.first

        @tag_name = tag_name
        @actual = span.get_tag(tag)

        if args.empty? && @actual
          # This condition enables the default matcher:
          # expect(foo).to have_error_tag
          return true
        end
