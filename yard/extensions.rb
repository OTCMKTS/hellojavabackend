# frozen_string_literal: true

TOP_LEVEL_MODULE_FILE = 'lib/ddtrace.rb'

# The top-level `Datadog` module gets its docstring overwritten by
# on almost every file in the repo, due to comments at the top of the file
# (e.g. '# typed: true' or from vendor files 'Copyright (c) 2001-2010 Not Datadog.')
#
# This module ensures that only the comment provided by 'lib/ddtrace.rb'
# is used as documentation for the top-level `Datadog` module.
#
# For non-top-level documentation, this can be solved by removing duplicate module/class
# documentation. But for top-level it's tricky, as it is common to leave general comments
# and directives in the first lines of a file.
module EnsureTopLevelModuleCommentConsistency
  def register_docstring(object, *args)
    if object.is_a?(YARD::CodeObjects::ModuleObject) && object.path == 'Datadog' && parser.file != TOP_LEVEL_MODULE_FILE
      super(object, nil)
    else
      super
    end
  end
end
YARD::Handlers::Base.prepend(EnsureTopLevelModuleCommentConsistency)

# Sanity check to ensure we haven't renamed the top-level module definition file.
YARD::Parser::SourceParser.before_parse_list do |files, _global_state|
  raise "Top-level module file not found: #{TOP_LEVEL_MODULE_FILE}. Has it been moved?" unless
    files.include?(TOP_LEVEL_MODULE_FILE)
end

# Hides all objects that are not part of the Public API from YARD docs.
YARD::Parser::SourceParser.after_parse_list do
  YARD::Registry.each do |obj|
    case obj
    when YARD::CodeObjects::ModuleObject, YARD::CodeObjects::ClassObject
      # Mark modules and classes as private if they are not tagged with @public_api
      unless obj.has_tag?('public_api')
        obj.visibility = :private
        next
      end
    else
      # Do not change visibility of individual objects.
      # We'll handle their visibility in their encomp