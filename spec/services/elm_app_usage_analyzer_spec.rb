# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::ElmAppUsageAnalyzer do
  let(:analyzer) { described_class.new }

  describe "#layout_apps" do
    let(:layout_content) { "const app = Elm.NavSidebar.init({ node: n })" }

    before do
      allow(Dir).to receive(:glob).and_call_original
      allow(File).to receive(:read).and_call_original
    end

    context "when a layout exists in app/views/layouts" do
      let(:layout_path) { Rails.root.join("app", "views", "layouts", "application.html.erb") }
      let(:result) { analyzer.layout_apps }

      before do
        allow(Dir).to receive(:glob)
          .with(Rails.root.join("app", "views", "layouts", "*.html.erb"))
          .and_return([layout_path.to_s])
        allow(File).to receive(:read).with(layout_path.to_s).and_return(layout_content)
      end

      it "includes the app from the layout" do
        expect(result).to eq(["NavSidebar"])
      end
    end

    context "when custom_view_paths includes a layout file" do
      let(:analyzer) { described_class.new(custom_view_paths: ["app/content/layouts/antoinette.html.erb"]) }
      let(:custom_layout_path) { Rails.root.join("app/content/layouts/antoinette.html.erb") }
      let(:custom_layout_content) { "const app = Elm.BundleGraph.init({ node: n })" }
      let(:result) { analyzer.layout_apps }

      before do
        allow(Dir).to receive(:glob)
          .with(Rails.root.join("app", "views", "layouts", "*.html.erb"))
          .and_return([])
        allow(File).to receive(:file?).and_call_original
        allow(File).to receive(:file?).with(custom_layout_path).and_return(true)
        allow(File).to receive(:read).with(custom_layout_path.to_s).and_return(custom_layout_content)
      end

      it "includes the app from the custom layout" do
        expect(result).to eq(["BundleGraph"])
      end
    end
  end

  describe "#elm_apps" do
    context "when no Elm apps in content" do
      let(:content) { "<div>Hello World</div>" }
      let(:result) { analyzer.elm_apps(content) }

      it "returns empty array" do
        expect(result).to eq([])
      end
    end

    context "when one Elm app init found" do
      let(:content) do
        <<~JS
          const app = Elm.CaseBuilder.init({
            node: container
          })
        JS
      end
      let(:result) { analyzer.elm_apps(content) }

      it "returns array with one ElmApp" do
        expect(result.length).to eq(1)
      end

      it "returns ElmApp with correct name" do
        expect(result.first.name).to eq("CaseBuilder")
      end
    end

    context "when multiple different Elm apps found" do
      let(:content) do
        <<~JS
          const app1 = Elm.SearchForm.init({ node: n1 })
          const app2 = Elm.LikeButton.init({ node: n2 })
        JS
      end
      let(:result) { analyzer.elm_apps(content) }

      it "returns array with two ElmApps" do
        expect(result.length).to eq(2)
      end

      it "returns first ElmApp with correct name" do
        expect(result.first.name).to eq("SearchForm")
      end

      it "returns second ElmApp with correct name" do
        expect(result.last.name).to eq("LikeButton")
      end
    end

    context "when same Elm app initialized multiple times" do
      let(:content) do
        <<~JS
          const app1 = Elm.LikeButton.init({ node: n1 })
          const app2 = Elm.LikeButton.init({ node: n2 })
          const app3 = Elm.LikeButton.init({ node: n3 })
        JS
      end
      let(:result) { analyzer.elm_apps(content) }

      it "returns array with one ElmApp" do
        expect(result.length).to eq(1)
      end

      it "returns ElmApp with correct name" do
        expect(result.first.name).to eq("LikeButton")
      end
    end

    context "when multiline Elm.init pattern" do
      let(:content) do
        <<~JS
          const app = Elm.PanelGallery.init(
            {
              node: container,
              flags: { data: "test" }
            }
          )
        JS
      end
      let(:result) { analyzer.elm_apps(content) }

      it "returns array with one ElmApp" do
        expect(result.length).to eq(1)
      end

      it "returns ElmApp with correct name" do
        expect(result.first.name).to eq("PanelGallery")
      end
    end
  end
end
