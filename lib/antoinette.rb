# frozen_string_literal: true

require_relative "antoinette/version"
require_relative "antoinette/services/partial_resolver"
require_relative "antoinette/services/layout_resolver"
require_relative "antoinette/services/elm_app_usage_analyzer"
require_relative "antoinette/services/weaver"
require_relative "antoinette/services/compile_elm"
require_relative "antoinette/services/concat_bundle"
require_relative "antoinette/services/inject_script_tag"
require_relative "antoinette/services/clear_script_tag"
require_relative "antoinette/cli/commands"
require_relative "antoinette/engine" if defined?(Rails::Engine)

module Antoinette
end
