# frozen_string_literal: true

require "haikunator"
require "json"

module Antoinette
  class Weaver
    Bundle = Struct.new(:name, :elm_apps, :templates)

    def initialize(
      elm_analyzer: ElmAppUsageAnalyzer.new,
      partial_resolver: PartialResolver.new,
      custom_view_paths: []
    )
      @elm_analyzer = elm_analyzer
      @partial_resolver = partial_resolver
      @custom_view_paths = custom_view_paths
    end

    def bundles
      @bundles ||= @elm_analyzer.layout_apps.then do |layout_apps|
        @elm_analyzer.mappings.map do |apps, templates|
          resolved_templates = resolve_templates_from_partials(templates)
          merged_apps = (apps + layout_apps).uniq.sort
          Bundle.new(
            Haikunator.haikunate,
            merged_apps,
            resolved_templates.sort
          )
        end.sort_by { |bundle| -bundle.elm_apps.count }
      end
    end

    def generate_json
      output = {bundles: bundles.map do |bundle|
        {
          name: bundle.name,
          elm_apps: bundle.elm_apps,
          templates: bundle.templates
        }
      end}
      output[:custom_view_paths] = @custom_view_paths if @custom_view_paths.any?
      JSON.pretty_generate(output)
    end

    def resolve_templates_from_partials(templates)
      templates.flat_map do |template|
        if template.start_with?("_") || template.include?("/_")
          partial_path = template.sub(%r{^app/views/}, "")
          @partial_resolver.resolve(partial_path).map do |parent|
            "app/views/#{parent}"
          end
        else
          template
        end
      end.uniq
    end
  end
end
