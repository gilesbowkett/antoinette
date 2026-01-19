# frozen_string_literal: true

require "dry/cli"
require "json"

module Antoinette
  module CLI
    def self.output
      Rails.env.test? ? StringIO.new : $stdout
    end

    module Commands
      extend Dry::CLI::Registry

      class Config < Dry::CLI::Command
        desc "Generate JSON configuration for Elm bundles"

        option :stdout, type: :boolean, default: false, desc: "Output to stdout instead of file"
        option :custom_views, type: :array, default: [], desc: "Additional view directories to scan"

        def call(stdout:, custom_views: [], **)
          out = Antoinette::CLI.output
          config_path = Rails.root.join("config", "antoinette.json")

          existing_config = if File.exist?(config_path)
            JSON.parse(File.read(config_path))
          else
            {}
          end
          existing_custom = existing_config["custom_view_paths"] || []
          existing_elm_path = existing_config["elm_path"] || "elm"
          all_custom_views = (existing_custom + custom_views).uniq

          analyzer = Antoinette::ElmAppUsageAnalyzer.new(
            skip: "layouts/",
            custom_view_paths: all_custom_views
          )
          weaver = Antoinette::Weaver.new(
            elm_analyzer: analyzer,
            custom_view_paths: all_custom_views
          )

          output = JSON.parse(weaver.generate_json)
          output["elm_path"] = existing_elm_path
          json_output = JSON.pretty_generate(output)

          if stdout
            out.puts json_output
          else
            File.write(config_path, json_output)
            out.puts "Generated #{config_path}"
          end
        end
      end

      class Build < Dry::CLI::Command
        desc "Build JavaScript bundles from config"

        def call(**)
          out = Antoinette::CLI.output
          config_path = Rails.root.join("config", "antoinette.json")
          config = JSON.parse(File.read(config_path))

          elm_path = config["elm_path"] || "elm"
          compiler = Antoinette::CompileElm.new(elm_path: elm_path)
          concatenator = Antoinette::ConcatBundle.new
          injector = Antoinette::InjectScriptTag.new

          config["bundles"].each do |bundle|
            out.puts "Building bundle: #{bundle["name"]}"

            elm_js = compiler.compile(bundle["elm_apps"])
            concatenator.concatenate(
              bundle_name: bundle["name"],
              elm_js: elm_js
            )

            bundle["templates"].each do |template_path|
              injector.inject(template_path: template_path, bundle_name: bundle["name"])
            end

            out.puts "  Compiled Elm apps: #{bundle["elm_apps"].join(", ")}"
            out.puts "  Injected script tags into #{bundle["templates"].length} template(s)"
          end

          out.puts "Build complete!"
        end
      end

      class Clear < Dry::CLI::Command
        desc "Clear generated bundles and script tags"

        def call(**)
          out = Antoinette::CLI.output
          config_path = Rails.root.join("config", "antoinette.json")
          config = JSON.parse(File.read(config_path))

          clearer = Antoinette::ClearScriptTag.new

          config["bundles"].each do |bundle|
            out.puts "Clearing bundle: #{bundle["name"]}"

            bundle_file = Rails.root.join(
              "app", "assets", "javascripts", "antoinette", "#{bundle["name"]}.js"
            )
            if File.exist?(bundle_file)
              File.delete(bundle_file)
              out.puts "  Deleted bundle file: #{bundle["name"]}.js"
            end

            bundle["templates"].each do |template_path|
              clearer.clear(template_path: template_path)
            end

            out.puts "  Cleared script tags from #{bundle["templates"].length} template(s)"
          end

          out.puts "Clear complete!"
        end
      end

      class Update < Dry::CLI::Command
        desc "Update bundle(s) and script tag(s) for specific Elm apps"

        argument :elm_files, type: :array, required: true, desc: "Elm file paths"

        def call(elm_files:, **)
          out = Antoinette::CLI.output
          elm_app_names = elm_files.map { |path| File.basename(path, ".elm") }

          config_path = Rails.root.join("config", "antoinette.json")
          config = JSON.parse(File.read(config_path))

          filtered_bundles = config["bundles"].select do |bundle|
            (bundle["elm_apps"] & elm_app_names).any?
          end

          if filtered_bundles.empty?
            out.puts "No bundles found containing: #{elm_app_names.join(", ")}"
            exit
          end

          elm_path = config["elm_path"] || "elm"
          compiler = Antoinette::CompileElm.new(elm_path: elm_path)
          concatenator = Antoinette::ConcatBundle.new
          injector = Antoinette::InjectScriptTag.new

          filtered_bundles.each do |bundle|
            out.puts "Updating bundle: #{bundle["name"]}"

            elm_js = compiler.compile(bundle["elm_apps"])
            concatenator.concatenate(
              bundle_name: bundle["name"],
              elm_js: elm_js
            )

            bundle["templates"].each do |template_path|
              injector.inject(template_path: template_path, bundle_name: bundle["name"])
            end

            out.puts "  Compiled Elm apps: #{bundle["elm_apps"].join(", ")}"
            out.puts "  Injected script tags into #{bundle["templates"].length} template(s)"
          end

          out.puts "Update complete!"
        end
      end

      register "config", Config
      register "build", Build
      register "clear", Clear
      register "update", Update
    end
  end
end
