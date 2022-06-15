require 'datadog/profiling/collectors/code_provenance'
require 'json-schema'

RSpec.describe Datadog::Profiling::Collectors::CodeProvenance do
  subject(:code_provenance) { described_class.new }

  describe '#refresh' do
    subject(:refresh) { code_provenance.refresh }

    it 'records libraries that are currently loaded' do
      refresh

      expect(code_provenance.generate).to include(
        have_attributes(
          kind: 'standard library',
          name: 'stdlib',
          version: RUBY_VERSION.to_s,
          path: start_with('/'),
        ),
        have_attributes(
          kind: 'library',
          name: 'ddtrace',
          version: DDTrace::VERSION::STRING,
          path: start_with('/'),
        ),
        have_attributes(
          kind: 'library',
          name: 'rspec-core',
          version: start_with('3.'), # This will one day need to be bumped for RSpec 4
          path: start_with('/'),
        )
      )
    end

    it 'records the correct path for ddtrace' do
      refresh

      current_file_directory = __dir__
      dd_trace_root_directory = code_provenance.generate.find { |lib| lib.name == 'ddtrace' }.path

      expect(current_file_directory).to start_with(dd_trace_root_directory)
    end

    it 'skips libraries not present in the loaded files' do
      code_provenance.refresh(
        loaded_files: ['/is_loaded/is_loaded.rb'],
        loaded_specs: [
          instance_double(
            Gem::Specification,
            name: 'not_loaded',
            version: 'not_loaded_version',
            gem_dir: '/not_loaded/'
          ),
          instance_double(
            Gem::Specification,
            name: 'is_loaded',
           