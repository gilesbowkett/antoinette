# frozen_string_literal: true

require "csv"

module Antoinette
  class ElmAppUsageAnalyzer
    ViewFile = Struct.new(:path, :elm_apps)
    ElmApp = Struct.new(:name)
    class Matrix < Hash; end

    def initialize(skip: nil, custom_view_paths: [])
      @skip = skip
      @custom_view_paths = custom_view_paths
    end

    def views
      @views ||= view_path_globs.each_with_object([]) do |glob_pattern, result|
        Dir.glob(glob_pattern).each do |file_path|
          content = File.read(file_path)
          apps = elm_apps(content)
          next if apps.empty?

          relative_path = file_path.sub("#{Rails.root}/", "")
          next if @skip && relative_path.include?("app/views/#{@skip}")

          app_names = apps.map(&:name)
          result << ViewFile.new(relative_path, app_names)
        end
      end
    end

    def view_path_globs
      globs = [Rails.root.join("app", "views", "**", "*.html.erb")]
      @custom_view_paths.each do |custom_path|
        full_path = Rails.root.join(custom_path)
        globs << if File.file?(full_path)
          full_path
        else
          full_path.join("**", "*.html.erb")
        end
      end
      globs
    end

    def elm_apps(content)
      app_names = content.scan(/Elm\.(\w+)\.init/).flatten.uniq
      app_names.map { |name| ElmApp.new(name) }
    end

    def matrix
      @matrix ||= Matrix.new.tap do |m|
        all_app_names.each do |app_name|
          m[app_name] = views.select { |v| v.elm_apps.include?(app_name) }
            .map(&:path)
        end
      end
    end

    def all_app_names
      @all_app_names ||= views.flat_map(&:elm_apps).uniq.sort
    end

    def layout_apps
      @layout_apps ||= layout_paths.flat_map do |file_path|
        content = File.read(file_path)
        elm_apps(content).map(&:name)
      end.uniq
    end

    def layout_paths
      paths = Dir.glob(Rails.root.join("app", "views", "layouts", "*.html.erb"))
      @custom_view_paths.each do |custom_path|
        next unless custom_path.include?("layouts/")

        full_path = Rails.root.join(custom_path)
        if File.file?(full_path)
          paths << full_path.to_s
        else
          paths.concat(Dir.glob(full_path.join("**", "*.html.erb")))
        end
      end
      paths
    end

    def per_file
      @per_file ||= views.sort_by { |vf| -vf.elm_apps.count }
        .each_with_object({}) do |view_file, result|
          result[view_file.path] = view_file.elm_apps
      end
    end

    def mappings
      @mappings ||= views.group_by { |vf| vf.elm_apps.sort }
        .sort_by { |apps, _| -apps.count }
        .each_with_object({}) do |(apps, view_files), result|
          result[apps] = view_files.map(&:path).sort
        end
    end

    def generate_csv
      CSV.generate do |csv|
        csv << ["View File"] + all_app_names

        views.each do |view_file|
          row = [view_file.path]
          all_app_names.each do |app_name|
            row << (view_file.elm_apps.include?(app_name) ? "X" : "")
          end
          csv << row
        end
      end
    end
  end
end
