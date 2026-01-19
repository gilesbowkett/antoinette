# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::PartialResolver do
  let(:resolver) { described_class.new }

  describe "#extract_partial_paths" do
    context "when no render calls in content" do
      let(:content) { "<div>Hello World</div>" }
      let(:result) { resolver.extract_partial_paths(content) }

      it "returns empty array" do
        expect(result).to eq([])
      end
    end

    context "when render partial: syntax with full path" do
      let(:content) do
        <<~ERB
          <%= render partial: "shared/module_card" %>
        ERB
      end
      let(:result) { resolver.extract_partial_paths(content) }

      it "returns array with one partial path" do
        expect(result.length).to eq(1)
      end

      it "returns normalized partial path" do
        expect(result.first).to eq("shared/_module_card.html.erb")
      end
    end

    context "when render shorthand syntax with full path" do
      let(:content) do
        <<~ERB
          <%= render "cases/baby_case" %>
        ERB
      end
      let(:result) { resolver.extract_partial_paths(content) }

      it "returns array with one partial path" do
        expect(result.length).to eq(1)
      end

      it "returns normalized partial path" do
        expect(result.first).to eq("cases/_baby_case.html.erb")
      end
    end

    context "when render partial: syntax with relative path" do
      let(:content) do
        <<~ERB
          <%= render partial: "form" %>
        ERB
      end
      let(:template_path) { "manufacturers/new.html.erb" }
      let(:result) do
        resolver.extract_partial_paths(content, template_path)
      end

      it "returns array with one partial path" do
        expect(result.length).to eq(1)
      end

      it "returns normalized partial path with template directory" do
        expect(result.first).to eq("manufacturers/_form.html.erb")
      end
    end

    context "when render shorthand syntax with relative path" do
      let(:content) do
        <<~ERB
          <%= render "baby_case" %>
        ERB
      end
      let(:template_path) { "cases/index.html.erb" }
      let(:result) do
        resolver.extract_partial_paths(content, template_path)
      end

      it "returns array with one partial path" do
        expect(result.length).to eq(1)
      end

      it "returns normalized partial path with template directory" do
        expect(result.first).to eq("cases/_baby_case.html.erb")
      end
    end

    context "when path already has underscore" do
      let(:content) do
        <<~ERB
          <%= render "_error_messages" %>
        ERB
      end
      let(:template_path) { "devise/registrations/new.html.erb" }
      let(:result) do
        resolver.extract_partial_paths(content, template_path)
      end

      it "does not add duplicate underscore" do
        expect(result.first).to eq("devise/registrations/_error_messages.html.erb")
      end
    end

    context "when nested directory path" do
      let(:content) do
        <<~ERB
          <%= render "devise/shared/links" %>
        ERB
      end
      let(:result) { resolver.extract_partial_paths(content) }

      it "preserves directory structure" do
        expect(result.first).to eq("devise/shared/_links.html.erb")
      end
    end

    context "when multiple render calls in content" do
      let(:content) do
        <<~ERB
          <%= render "shared/header" %>
          <%= render partial: "shared/footer" %>
        ERB
      end
      let(:result) { resolver.extract_partial_paths(content) }

      it "returns array with two partial paths" do
        expect(result.length).to eq(2)
      end

      it "returns first normalized partial path" do
        expect(result).to include("shared/_header.html.erb")
      end

      it "returns second normalized partial path" do
        expect(result).to include("shared/_footer.html.erb")
      end
    end

    context "when same partial rendered multiple times" do
      let(:content) do
        <<~ERB
          <%= render "cases/baby_case" %>
          <%= render partial: "cases/baby_case" %>
        ERB
      end
      let(:result) { resolver.extract_partial_paths(content) }

      it "returns array with one partial path" do
        expect(result.length).to eq(1)
      end

      it "returns normalized partial path" do
        expect(result.first).to eq("cases/_baby_case.html.erb")
      end
    end
  end

  describe "#normalize_partial_path" do
    context "when path includes directory" do
      let(:path) { "shared/module_card" }
      let(:result) { resolver.normalize_partial_path(path) }

      it "adds underscore prefix to filename" do
        expect(result).to eq("shared/_module_card.html.erb")
      end
    end

    context "when path already has underscore" do
      let(:path) { "shared/_module_card" }
      let(:result) { resolver.normalize_partial_path(path) }

      it "does not add duplicate underscore" do
        expect(result).to eq("shared/_module_card.html.erb")
      end
    end

    context "when path has no directory and no template path provided" do
      let(:path) { "form" }
      let(:result) { resolver.normalize_partial_path(path) }

      it "adds underscore prefix to filename" do
        expect(result).to eq("_form.html.erb")
      end
    end

    context "when path has no directory and template path provided" do
      let(:path) { "baby_case" }
      let(:template_path) { "cases/index.html.erb" }
      let(:result) { resolver.normalize_partial_path(path, template_path) }

      it "uses template directory for partial path" do
        expect(result).to eq("cases/_baby_case.html.erb")
      end
    end

    context "when relative path already has underscore and template path provided" do
      let(:path) { "_error_messages" }
      let(:template_path) { "devise/registrations/new.html.erb" }
      let(:result) { resolver.normalize_partial_path(path, template_path) }

      it "does not add duplicate underscore" do
        expect(result).to eq("devise/registrations/_error_messages.html.erb")
      end
    end

    context "when path has nested directories" do
      let(:path) { "devise/shared/links" }
      let(:result) { resolver.normalize_partial_path(path) }

      it "preserves directory structure and adds underscore to filename" do
        expect(result).to eq("devise/shared/_links.html.erb")
      end
    end
  end
end
