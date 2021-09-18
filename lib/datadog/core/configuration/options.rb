require_relative 'option_set'
require_relative 'option_definition'
require_relative 'option_definition_set'

module Datadog
  module Core
    module Configuration
      # Behavior for a configuration object that has options
      # @public_api
      module Options
        def self.included(base)
          base.extend(ClassMethods)
          base.include(InstanceMethods)
        end

        # Class behavior for a configuration object with options
        # @public_api
        module ClassMethods
          def options
            # Allows for class inheritance of option definitions
            @options ||= superclass <= Options ? superclass.options.dup : OptionDefinitionSet.new
          end

          protected

          def option(name, meta = {}, &block)
            builder = OptionDefinition::Builder.new(name, meta, &block)
            options[name] = builder.to_definition.tap do