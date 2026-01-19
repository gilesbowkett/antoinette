# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::ClearScriptTag do
  let(:views_path) { Pathname.new("/tmp/test_views") }
  let(:clearer) { described_class.new(views_path: views_path) }
  let(:template_path) { "cases/new.html.erb" }
  let(:full_path) { views_path.join(template_path) }

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:write)
  end

  describe "#clear" do
    context "when template has antoinette tag" do
      let(:original_content) do
        <<~ERB
          <h1>New Case</h1>
          <%= render 'form' %>
          <%= javascript_include_tag "holy-waterfall-8432" %> <!-- antoinette a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->
        ERB
      end

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "removes antoinette script tag line" do
        clearer.clear(template_path: template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).not_to include("antoinette")
        end
      end

      it "removes javascript_include_tag from line" do
        clearer.clear(template_path: template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).not_to include("javascript_include_tag")
        end
      end

      it "preserves other content" do
        clearer.clear(template_path: template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("<h1>New Case</h1>")
        end
      end

      it "preserves render calls" do
        clearer.clear(template_path: template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include("render 'form'")
        end
      end
    end

    context "when template has antoinette tag and other script tags" do
      let(:original_content) do
        <<~ERB
          <h1>New Case</h1>
          <%= javascript_include_tag "application" %>
          <%= javascript_include_tag "holy-waterfall-8432" %> <!-- antoinette a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2 -->
        ERB
      end

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "removes only antoinette script tag" do
        clearer.clear(template_path: template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).not_to include("antoinette")
        end
      end

      it "preserves other script tags" do
        clearer.clear(template_path: template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).to include('javascript_include_tag "application"')
        end
      end
    end

    context "when template has no antoinette tag" do
      let(:original_content) do
        <<~ERB
          <h1>New Case</h1>
          <%= render 'form' %>
        ERB
      end

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "does not write to file" do
        clearer.clear(template_path: template_path)
        expect(File).not_to have_received(:write)
      end
    end

    context "when template has only other script tags" do
      let(:original_content) do
        <<~ERB
          <h1>New Case</h1>
          <%= javascript_include_tag "application" %>
        ERB
      end

      before do
        allow(File).to receive(:read).with(full_path).and_return(original_content)
      end

      it "does not write to file" do
        clearer.clear(template_path: template_path)
        expect(File).not_to have_received(:write)
      end
    end

    context "when template path starts with app/" do
      let(:custom_template_path) { "app/content/layouts/blog.html.erb" }
      let(:custom_full_path) { Rails.root.join(custom_template_path) }
      let(:original_content) do
        <<~ERB
          <h1>Blog</h1>
          <%= javascript_include_tag "bundle" %> <!-- antoinette abc123def456 -->
        ERB
      end

      before do
        allow(File).to receive(:read)
          .with(custom_full_path)
          .and_return(original_content)
      end

      it "resolves path relative to Rails.root" do
        clearer.clear(template_path: custom_template_path)
        expect(File).to have_received(:write).with(custom_full_path, anything)
      end

      it "removes antoinette script tag from custom view template" do
        clearer.clear(template_path: custom_template_path)
        expect(File).to have_received(:write) do |_path, content|
          expect(content).not_to include("antoinette")
        end
      end
    end

    context "when template path does not start with app/" do
      let(:legacy_template_path) { "cases/new.html.erb" }
      let(:legacy_full_path) { views_path.join(legacy_template_path) }
      let(:original_content) do
        <<~ERB
          <h1>New Case</h1>
          <%= javascript_include_tag "bundle" %> <!-- antoinette abc123def456 -->
        ERB
      end

      before do
        allow(File).to receive(:read)
          .with(legacy_full_path)
          .and_return(original_content)
      end

      it "resolves path relative to views_path" do
        clearer.clear(template_path: legacy_template_path)
        expect(File).to have_received(:write).with(legacy_full_path, anything)
      end
    end
  end
end
