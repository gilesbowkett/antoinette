# frozen_string_literal: true

require "yaml"

module Antoinette
  class LayoutResolver
    def initialize(layout_dirs: ["app/views/layouts"], default_layout: "application")
      @layout_dirs = layout_dirs
      @default_layout = default_layout
    end

    def layout_apps_map
      @layout_apps_map ||= @layout_dirs.each_with_object({}) do |dir, result|
        Dir.glob(Rails.root.join(dir, "*.html.erb")).each do |file_path|
          content = File.read(file_path)
          apps = content.scan(/Elm\.(\w+)\.init/).flatten.uniq
          name = File.basename(file_path, ".html.erb")
          result[name] = ((result[name] || []) + apps).uniq
        end
      end
    end

    def layout_for(template_path)
      full_path = if Pathname.new(template_path).absolute?
        template_path
      else
        Rails.root.join(template_path).to_s
      end

      return @default_layout unless File.exist?(full_path)

      content = File.read(full_path)
      return @default_layout unless content.start_with?("---")

      frontmatter = content.match(/\A---\s*\n(.*?\n)---/m)
      return @default_layout unless frontmatter

      yaml = YAML.safe_load(frontmatter[1])
      yaml&.fetch("layout", @default_layout) || @default_layout
    end

    def apps_for(template_path)
      layout = layout_for(template_path)
      layout_apps_map[layout] || []
    end
  end
end
