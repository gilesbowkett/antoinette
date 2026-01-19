# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::Weaver do
  let(:layout_apps) { [] }
  let(:elm_analyzer) do
    instance_double(Antoinette::ElmAppUsageAnalyzer, mappings: mappings, layout_apps: layout_apps)
  end
  let(:partial_resolver) { instance_double(Antoinette::PartialResolver) }
  let(:weaver) do
    described_class.new(
      elm_analyzer: elm_analyzer,
      partial_resolver: partial_resolver
    )
  end

  describe "#bundles" do
    let(:mappings) do
      {
        ["CaseBuilder", "SearchForm"] => [
          "cases/new.html.erb",
          "cases/show.html.erb"
        ],
        ["PanelGallery"] => ["eurorack_modules/show.html.erb"]
      }
    end

    before do
      allow(partial_resolver).to receive(:resolve).and_return([])
    end

    let(:result) { weaver.bundles }

    it "returns array of Bundle structs" do
      expect(result).to be_an(Array)
    end

    it "returns Bundles with name attribute" do
      expect(result.first).to respond_to(:name)
    end

    it "returns Bundles with elm_apps attribute" do
      expect(result.first).to respond_to(:elm_apps)
    end

    it "returns Bundles with templates attribute" do
      expect(result.first).to respond_to(:templates)
    end

    it "creates bundle for each mapping" do
      expect(result.length).to eq(2)
    end

    context "when examining bundle with CaseBuilder" do
      let(:bundle) do
        result.find { it.elm_apps.include?("CaseBuilder") }
      end

      it "sets elm_apps from mapping keys" do
        expect(bundle.elm_apps).to eq(["CaseBuilder", "SearchForm"])
      end
    end

    context "when examining bundle with PanelGallery" do
      let(:bundle) do
        result.find { it.elm_apps.include?("PanelGallery") }
      end

      it "sets templates from mapping values" do
        expect(bundle.templates).to eq(["eurorack_modules/show.html.erb"])
      end
    end

    it "generates haikunated name for each bundle" do
      expect(result.first.name).to be_a(String)
    end

    context "when checking name uniqueness" do
      let(:names) { result.map(&:name) }

      it "generates unique names for different bundles" do
        expect(names.uniq.length).to eq(names.length)
      end
    end

    context "sort order" do
      it "places bundle with more apps first" do
        expect(result.first.elm_apps.count).to eq(2)
      end

      it "places bundle with fewer apps second" do
        expect(result.last.elm_apps.count).to eq(1)
      end
    end

    context "when templates include partials" do
      let(:mappings) do
        {
          ["BabyCaseBuilder"] => ["app/views/cases/_baby_case.html.erb"]
        }
      end
      let(:parent_templates) do
        ["cases/index.html.erb", "users/show.html.erb"]
      end

      before do
        allow(partial_resolver).to receive(:resolve)
          .with("cases/_baby_case.html.erb")
          .and_return(parent_templates)
      end

      let(:bundle) { result.first }

      it "resolves partials to parent templates" do
        expect(bundle.templates).to include("app/views/cases/index.html.erb")
      end

      it "includes all parent templates" do
        expect(bundle.templates).to include("app/views/users/show.html.erb")
      end

      it "alphabetizes templates" do
        expect(bundle.templates).to eq(bundle.templates.sort)
      end
    end

    context "when called multiple times" do
      let(:first_call) { weaver.bundles }
      let(:second_call) { weaver.bundles }

      it "memoizes results in instance variable" do
        expect(first_call.object_id).to eq(second_call.object_id)
      end
    end

    context "when layout apps exist" do
      let(:mappings) do
        {
          ["CaseBuilder"] => ["cases/new.html.erb"],
          ["PanelGallery"] => ["eurorack_modules/show.html.erb"]
        }
      end
      let(:layout_apps) { ["NavSidebar"] }

      before do
        allow(partial_resolver).to receive(:resolve).and_return([])
      end

      let(:case_bundle) do
        result.find { it.elm_apps.include?("CaseBuilder") }
      end
      let(:panel_bundle) do
        result.find { it.elm_apps.include?("PanelGallery") }
      end

      it "merges layout apps into CaseBuilder bundle" do
        expect(case_bundle.elm_apps).to include("NavSidebar")
      end

      it "merges layout apps into PanelGallery bundle" do
        expect(panel_bundle.elm_apps).to include("NavSidebar")
      end

      it "alphabetizes merged elm_apps" do
        expect(case_bundle.elm_apps).to eq(case_bundle.elm_apps.sort)
      end

      it "removes duplicate apps if layout app already in bundle" do
        expect(case_bundle.elm_apps.count("NavSidebar")).to eq(1)
      end
    end
  end

  describe "#generate_json" do
    let(:mappings) do
      {
        ["CaseBuilder"] => ["cases/new.html.erb"],
        ["PanelGallery"] => ["eurorack_modules/show.html.erb"]
      }
    end

    before do
      allow(partial_resolver).to receive(:resolve).and_return([])
    end

    let(:result) { weaver.generate_json }
    let(:parsed) { JSON.parse(result) }

    it "returns JSON string" do
      expect(result).to be_a(String)
    end

    it "includes bundles key" do
      expect(parsed).to have_key("bundles")
    end

    it "bundles is an array" do
      expect(parsed["bundles"]).to be_an(Array)
    end

    it "includes bundle with name" do
      expect(parsed["bundles"].first).to have_key("name")
    end

    it "includes bundle with elm_apps" do
      expect(parsed["bundles"].first).to have_key("elm_apps")
    end

    it "includes bundle with templates" do
      expect(parsed["bundles"].first).to have_key("templates")
    end

    context "when examining bundle with CaseBuilder" do
      let(:bundle) do
        parsed["bundles"].find { it["elm_apps"].include?("CaseBuilder") }
      end

      it "elm_apps contains app names" do
        expect(bundle["elm_apps"]).to eq(["CaseBuilder"])
      end
    end

    context "when examining bundle with PanelGallery" do
      let(:bundle) do
        parsed["bundles"].find do
          it["elm_apps"].include?("PanelGallery")
        end
      end

      it "templates contains template paths" do
        expect(bundle["templates"]).to eq(["eurorack_modules/show.html.erb"])
      end
    end

    context "when custom_view_paths provided" do
      let(:custom_view_paths) { ["app/content/layouts"] }
      let(:weaver) do
        described_class.new(
          elm_analyzer: elm_analyzer,
          partial_resolver: partial_resolver,
          custom_view_paths: custom_view_paths
        )
      end

      it "includes custom_view_paths in JSON output" do
        expect(parsed).to have_key("custom_view_paths")
      end

      it "custom_view_paths contains the paths" do
        expect(parsed["custom_view_paths"]).to eq(["app/content/layouts"])
      end
    end

    context "when custom_view_paths is empty" do
      let(:custom_view_paths) { [] }
      let(:weaver) do
        described_class.new(
          elm_analyzer: elm_analyzer,
          partial_resolver: partial_resolver,
          custom_view_paths: custom_view_paths
        )
      end

      it "does not include custom_view_paths key" do
        expect(parsed).not_to have_key("custom_view_paths")
      end
    end
  end
end
