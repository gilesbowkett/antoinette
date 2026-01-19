# frozen_string_literal: true

module Antoinette
  class Engine < ::Rails::Engine
    initializer "antoinette.assets" do |app|
      app.config.assets.paths << root.join("app", "assets", "javascripts")
    end

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
