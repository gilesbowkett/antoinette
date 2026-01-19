# frozen_string_literal: true

module Antoinette
  class ConcatBundle
    def initialize(assets_path: Rails.root.join("app", "assets", "javascripts", "antoinette"))
      @assets_path = assets_path
    end

    def concatenate(bundle_name:, elm_js:)
      output_path = @assets_path.join("#{bundle_name}.js")
      File.write(output_path, elm_js)

      output_path.to_s
    end
  end
end
