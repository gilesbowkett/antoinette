# frozen_string_literal: true

require "digest"

module Antoinette
  class InjectScriptTag
    def initialize(
      assets_path: Rails.root.join("app", "assets", "javascripts", "antoinette")
    )
      @assets_path = assets_path
    end

    def inject(template_path:, bundle_name:)
      full_path = Rails.root.join(template_path)
      content = File.read(full_path)

      bundle_path = @assets_path.join("#{bundle_name}.js")
      digest = Digest::SHA1.hexdigest(File.read(bundle_path))
      script_tag = "<%= javascript_include_tag \"antoinette/#{bundle_name}\" %> <!-- antoinette #{digest} -->"

      updated_content = if content.match?(/<!-- antoinette [a-f0-9]+ -->/)
        content.gsub(/^.*<!-- antoinette [a-f0-9]+ -->.*$/, script_tag)
      else
        content + "\n" + script_tag
      end

      File.write(full_path, updated_content)
    end
  end
end
