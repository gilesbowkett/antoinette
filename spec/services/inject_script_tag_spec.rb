# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::InjectScriptTag do
  let(:assets_path) { Pathname.new("/tmp/test_assets") }
  let(:injector) { described_class.new(assets_path: assets_path) }
  let(:template_path) { "app/views/cases/new.html.erb" }
  let(:bundle_name) { "holy-waterfall-8432" }
  let(:full_path) { Rails.root.join(template_path) }
  let(:bundle_path) { assets_path.join("#{bundle_name}.js") }
  let(:bundle_content) { "// compiled elm js content" }
  let(:expected_digest) { Digest::SHA1.hexdigest(bundle_content) }

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(bundle_path).and_return(bundle_content)
    allow(File).to receive(:write)
  end

  describe "#inject" do
    context "when template has no existing antoinette tag" do
      let(:original_content) { "<h1>New Case</h1>\n<%= render 'form' %>" }

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "inserts script tag at bottom of file" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to end_with("<!-- antoinette #{expected_digest} -->")
        end
      end

      it "includes bundle name in script tag" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("javascript_include_tag \"antoinette/holy-waterfall-8432\"")
        end
      end

      it "includes antoinette comment with digest" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("<!-- antoinette #{expected_digest} -->")
        end
      end

      it "preserves original content" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("<h1>New Case</h1>")
        end
      end

      it "places script tag after original content" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content.index("<h1>New Case</h1>")).to be < content.index("javascript_include_tag")
        end
      end
    end

    context "when template has existing antoinette tag" do
      let(:old_digest) { "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2" }
      let(:original_content) do
        <<~ERB
          <%= javascript_include_tag "old-bundle-name" %> <!-- antoinette #{old_digest} -->
          <h1>New Case</h1>
          <%= render 'form' %>
        ERB
      end

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "replaces existing script tag" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("javascript_include_tag \"antoinette/holy-waterfall-8432\"")
        end
      end

      it "removes old bundle name" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).not_to include("old-bundle-name")
        end
      end

      it "updates digest" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("<!-- antoinette #{expected_digest} -->")
        end
      end

      it "removes old digest" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).not_to include(old_digest)
        end
      end

      it "preserves original content" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("<h1>New Case</h1>")
        end
      end

      it "maintains single script tag" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content.scan("javascript_include_tag").length).to eq(1)
        end
      end
    end

    context "when called twice with same bundle content" do
      let(:original_content) { "<h1>New Case</h1>" }

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "produces single script tag after first call" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write) do |_path, content|
          expect(content.scan("javascript_include_tag").length).to eq(1)
        end
      end

      context "after first injection" do
        let(:content_after_first_injection) do
          "<%= javascript_include_tag \"holy-waterfall-8432\" %> " \
            "<!-- antoinette #{expected_digest} -->\n<h1>New Case</h1>"
        end

        before do
          injector.inject(template_path: template_path, bundle_name: bundle_name)
          allow(File).to receive(:read)
            .with(full_path)
            .and_return(content_after_first_injection)
        end

        it "produces single script tag after second call" do
          injector.inject(template_path: template_path, bundle_name: bundle_name)
          expect(File).to have_received(:write).twice do |_path, content|
            expect(content.scan("javascript_include_tag").length).to eq(1)
          end
        end

        it "produces same digest when bundle content unchanged" do
          injector.inject(template_path: template_path, bundle_name: bundle_name)
          expect(File).to have_received(:write).with(full_path, /#{expected_digest}/).twice
        end
      end
    end

    context "when bundle content changes between calls" do
      let(:original_content) { "<h1>New Case</h1>" }
      let(:new_bundle_content) { "// updated elm js content" }
      let(:new_digest) { Digest::SHA1.hexdigest(new_bundle_content) }
      let(:content_after_first_injection) do
        "<%= javascript_include_tag \"holy-waterfall-8432\" %> " \
          "<!-- antoinette #{expected_digest} -->\n<h1>New Case</h1>"
      end

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        allow(File).to receive(:read)
          .with(full_path)
          .and_return(content_after_first_injection)
        allow(File).to receive(:read)
          .with(bundle_path)
          .and_return(new_bundle_content)
      end

      it "produces different digest for different content" do
        injector.inject(template_path: template_path, bundle_name: bundle_name)
        expect(File).to have_received(:write).with(full_path, /#{new_digest}/)
      end
    end

    context "with custom view path outside app/views" do
      let(:custom_template_path) { "app/content/layouts/blog.html.erb" }
      let(:custom_full_path) { Rails.root.join(custom_template_path) }
      let(:original_content) { "<h1>Blog</h1>" }

      before do
        allow(File).to receive(:read)
          .with(custom_full_path)
          .and_return(original_content)
      end

      it "resolves path relative to Rails.root" do
        injector.inject(
          template_path: custom_template_path,
          bundle_name: bundle_name
        )
        expect(File).to have_received(:write).with(custom_full_path, anything)
      end

      it "injects script tag into custom view template" do
        injector.inject(
          template_path: custom_template_path,
          bundle_name: bundle_name
        )
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("javascript_include_tag")
        end
      end
    end
  end
end
