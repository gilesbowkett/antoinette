# frozen_string_literal: true

module Antoinette
  class ClearScriptTag
    def initialize(views_path: Rails.root.join("app", "views"))
      @views_path = views_path
    end

    def clear(template_path:)
      full_path = resolve_template_path(template_path)
      content = File.read(full_path)

      return unless content.match?(InjectScriptTag::MARKER)

      updated_content = content.gsub(/^.*#{InjectScriptTag::MARKER}.*\n?/o, "")

      File.write(full_path, updated_content)
    end

    private

    def resolve_template_path(template_path)
      if template_path.start_with?("app/")
        Rails.root.join(template_path)
      else
        @views_path.join(template_path)
      end
    end
  end
end
