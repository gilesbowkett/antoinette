# frozen_string_literal: true

module Antoinette
  class InjectScriptTag
    MARKER = /<!-- antoinette( [a-f0-9]+)? -->/

    def inject(template_path:, bundle_name:)
      full_path = Rails.root.join(template_path)
      content = File.read(full_path)

      script_tag = "<%= javascript_include_tag \"antoinette/#{bundle_name}\" %> <!-- antoinette -->"

      updated_content = if content.match?(MARKER)
        content.gsub(/^.*#{MARKER}.*$/, script_tag)
      else
        content + "\n" + script_tag
      end

      File.write(full_path, updated_content)
    end
  end
end
