# frozen_string_literal: true

module Antoinette
  class PartialResolver
    RenderCall = Struct.new(:template_path, :partial_path)

    def renders
      @renders ||= begin
        view_files = Dir.glob(Rails.root.join("app", "views", "**", "*.html.erb"))

        view_files.each_with_object([]) do |file_path, result|
          content = File.read(file_path)
          relative_template_path = file_path.sub("#{Rails.root}/app/views/", "")
          partial_paths = extract_partial_paths(content, relative_template_path)
          next if partial_paths.empty?

          partial_paths.each do |partial_path|
            result << RenderCall.new(relative_template_path, partial_path)
          end
        end
      end
    end

    def extract_partial_paths(content, template_path = nil)
      paths = []

      content.scan(/render\s+partial:\s*["']([^"']+)["']/) do |match|
        paths << normalize_partial_path(match[0], template_path)
      end

      content.scan(/render\s+["']([^"']+)["']/) do |match|
        paths << normalize_partial_path(match[0], template_path)
      end

      paths.uniq
    end

    def normalize_partial_path(path, template_path = nil)
      if path.include?("/")
        dir, name = path.split("/")[0..-2].join("/"), path.split("/").last
        name = name.start_with?("_") ? name : "_#{name}"
        "#{dir}/#{name}.html.erb"
      else
        name = path.start_with?("_") ? path : "_#{path}"

        if template_path
          template_dir = File.dirname(template_path)
          "#{template_dir}/#{name}.html.erb"
        else
          "#{name}.html.erb"
        end
      end
    end

    def partials
      @partials ||= begin
        grouped = renders.group_by(&:partial_path)
        grouped.transform_values do |render_calls|
          render_calls.map(&:template_path).sort
        end
      end
    end

    def resolve(partial_path)
      partials[partial_path] || []
    end
  end
end
