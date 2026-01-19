# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"

require "rails"
require "action_controller/railtie"
require "action_view/railtie"

# Create a minimal Rails application for testing
module TestApp
  class Application < Rails::Application
    config.eager_load = false
    config.root = File.expand_path("..", __dir__)
  end
end

Rails.application.initialize!

require "rspec/rails"
require "antoinette"

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
