# frozen_string_literal: true

require "rails/generators"
require "rails/generators/base"

module Antoinette
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install Antoinette into your Rails application"

      def create_config_file
        create_file "config/antoinette.json", <<~JSON
          {
            "elm_path": "elm",
            "bundles": []
          }
        JSON
      end

      def create_client_directory
        empty_directory "app/client"
      end

      def copy_elm_files
        copy_file "BundleGraph.elm", "app/client/BundleGraph.elm"
        copy_file "Sankey.elm", "app/client/Sankey.elm"
      end

      def install_elm_dependencies
        say "Installing Elm dependencies..."
        run "elm install elm/browser"
        run "elm install elm/html"
        run "elm install elm/json"
        run "elm install elm/svg"
      end

      def copy_controller
        copy_file "graph_controller.rb", "app/controllers/antoinette/graph_controller.rb"
      end

      def copy_view
        copy_file "show.html.erb", "app/views/antoinette/graph/show.html.erb"
      end

      def create_antoinette_binstub
        create_file "bin/antoinette", <<~RUBY
          #!/usr/bin/env ruby
          require_relative "../config/environment"
          Dry::CLI.new(Antoinette::CLI::Commands).call
        RUBY
        chmod "bin/antoinette", 0o755
      end

      def create_assets_directory
        empty_directory "app/assets/javascripts/antoinette"
      end

      def update_gitignore
        gitignore_path = Rails.root.join(".gitignore")
        ignore_line = "app/assets/javascripts/antoinette/"

        if File.exist?(gitignore_path) && !File.read(gitignore_path).include?(ignore_line)
          append_to_file ".gitignore", "#{ignore_line}\n"
        end
      end

      def add_routes
        route_content = <<~RUBY
          get "/antoinette", to: "antoinette/graph#show"
        RUBY

        route route_content
      end

      def show_post_install_message
        say ""
        say "Antoinette has been installed!", :green
        say ""
        say "Next steps:"
        say "  1. Run `bin/antoinette config` to generate bundle configuration"
        say "  2. Run `bin/antoinette build` to compile Elm bundles"
        say ""
      end
    end
  end
end
