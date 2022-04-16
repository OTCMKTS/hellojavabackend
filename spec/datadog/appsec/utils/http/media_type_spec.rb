require 'datadog/appsec/utils/http/media_type'

RSpec.describe Datadog::AppSec::Utils::HTTP::MediaType do
  describe '.new' do
    context 'with valid input' do
      expectations = {
        '*/*' => { type: '*', subtype: '*' },
        'text/*' => { type: 'text', subtype: '*' },
        'text/html' => { type: 'text', subtype: 'html' },
        'Text/HTML' => { type: 'text', subtype: 'html' },
        'text/plain;format=flowed' => { type: 'text', subtype: 'plain', parameters: { 'format' => 'flowed' } },
        'Text/PLAIN;FORMAT=FLOWED' => { type: 'text', subtype: 'plain', parameters: { 'format' => 'flowed' } },
        'text/plain ; format=flowed' => { type: 'text', subtype: 'plain', parameters: { 'format' => 'flowed' } },
        'text/plain; format=flowed' => { type: 'text', subtype: 'plain', parameters: { 'format' => 'flowed' } },
        'text/plain ;format=flowed' => { type: 'text', subtype: 'plain', parameters: { 'format' => 'flowed' } },
        'application/json' => { type: 'application', subtype: 'json' },
      }

      expectations.each do |str, expected|
        it "parses #{str.inspect} to #{expected.inspect}" do
          expect(described_class.new(str)).to have_attributes expected
        end
      end
    end

    context 'with invalid input' do
      parse_error = described_class::P