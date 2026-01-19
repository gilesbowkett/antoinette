# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::ConcatBundle do
  let(:assets_path) { Pathname.new("/tmp/test_assets") }
  let(:concatenator) { described_class.new(assets_path: assets_path) }
  let(:bundle_name) { "holy-waterfall-8432" }
  let(:elm_js) { "// compiled elm code" }

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:write)
  end

  describe "#concatenate" do
    let(:result) do
      concatenator.concatenate(
        bundle_name: bundle_name,
        elm_js: elm_js
      )
    end

    it "returns output path" do
      expect(result).to eq("/tmp/test_assets/holy-waterfall-8432.js")
    end

    it "writes bundle file" do
      result
      expect(File).to have_received(:write)
        .with(Pathname.new("/tmp/test_assets/holy-waterfall-8432.js"), anything)
    end

    it "includes elm js content" do
      result
      expect(File).to have_received(:write)
        .with(anything, /\/\/ compiled elm code/)
    end
  end
end
