# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::CLI::Commands do
  describe Antoinette::CLI::Commands::Config do
    let(:command) { described_class.new }
    let(:analyzer) { instance_double(Antoinette::ElmAppUsageAnalyzer) }
    let(:weaver) { instance_double(Antoinette::Weaver) }
    let(:json_output) { '{"bundles": []}' }
    let(:output_path) { Rails.root.join("config", "antoinette.json") }

    before do
      allow(Antoinette::ElmAppUsageAnalyzer).to receive(:new).and_return(analyzer)
      allow(Antoinette::Weaver).to receive(:new).and_return(weaver)
      allow(weaver).to receive(:generate_json).and_return(json_output)
      allow(File).to receive(:write)
    end

    context "without stdout option" do
      let(:options) { {stdout: false} }

      it "calls ElmAppUsageAnalyzer with skip parameter" do
        command.call(**options)
        expect(Antoinette::ElmAppUsageAnalyzer).to have_received(:new)
          .with(hash_including(skip: "layouts/"))
      end

      it "calls Weaver with analyzer" do
        command.call(**options)
        expect(Antoinette::Weaver).to have_received(:new)
          .with(hash_including(elm_analyzer: analyzer))
      end

      it "calls generate_json on weaver" do
        command.call(**options)
        expect(weaver).to have_received(:generate_json)
      end

      it "writes to config file" do
        command.call(**options)
        expect(File).to have_received(:write).with(output_path, json_output)
      end
    end

    context "with stdout option" do
      let(:options) { {stdout: true} }

      it "calls ElmAppUsageAnalyzer with skip parameter" do
        command.call(**options)
        expect(Antoinette::ElmAppUsageAnalyzer).to have_received(:new)
          .with(hash_including(skip: "layouts/"))
      end

      it "calls Weaver with analyzer" do
        command.call(**options)
        expect(Antoinette::Weaver).to have_received(:new)
          .with(hash_including(elm_analyzer: analyzer))
      end

      it "calls generate_json on weaver" do
        command.call(**options)
        expect(weaver).to have_received(:generate_json)
      end

      it "does not write to file" do
        command.call(**options)
        expect(File).not_to have_received(:write)
      end
    end
  end

  describe Antoinette::CLI::Commands::Build do
    let(:command) { described_class.new }
    let(:config_path) { Rails.root.join("config", "antoinette.json") }
    let(:config) do
      {
        "bundles" => [
          {
            "name" => "bundle-1",
            "elm_apps" => ["App1"],
            "templates" => ["view1.html.erb"]
          }
        ]
      }
    end
    let(:compiler) { instance_double(Antoinette::CompileElm) }
    let(:concatenator) { instance_double(Antoinette::ConcatBundle) }
    let(:injector) { instance_double(Antoinette::InjectScriptTag) }
    let(:elm_js) { "// compiled elm" }

    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(config_path).and_return(config.to_json)
      allow(Antoinette::CompileElm).to receive(:new).and_return(compiler)
      allow(Antoinette::ConcatBundle).to receive(:new).and_return(concatenator)
      allow(Antoinette::InjectScriptTag).to receive(:new).and_return(injector)
      allow(compiler).to receive(:compile).and_return(elm_js)
      allow(concatenator).to receive(:concatenate)
      allow(injector).to receive(:inject)
    end

    it "reads config file" do
      command.call
      expect(File).to have_received(:read).with(config_path)
    end

    it "calls CompileElm with elm_apps from bundle" do
      command.call
      expect(compiler).to have_received(:compile).with(["App1"])
    end

    it "calls ConcatBundle with bundle_name and elm_js" do
      command.call
      expect(concatenator).to have_received(:concatenate).with(
        bundle_name: "bundle-1",
        elm_js: elm_js
      )
    end

    it "calls InjectScriptTag for each template" do
      command.call
      expect(injector).to have_received(:inject).with(
        template_path: "view1.html.erb",
        bundle_name: "bundle-1"
      )
    end

    context "with multiple bundles" do
      let(:config) do
        {
          "bundles" => [
            {
              "name" => "bundle-1",
              "elm_apps" => ["App1"],
              "templates" => ["view1.html.erb"]
            },
            {
              "name" => "bundle-2",
              "elm_apps" => ["App2"],
              "templates" => ["view2.html.erb"]
            }
          ]
        }
      end

      it "processes first bundle" do
        command.call
        expect(compiler).to have_received(:compile).with(["App1"])
      end

      it "processes second bundle" do
        command.call
        expect(compiler).to have_received(:compile).with(["App2"])
      end
    end
  end

  describe Antoinette::CLI::Commands::Clear do
    let(:command) { described_class.new }
    let(:config_path) { Rails.root.join("config", "antoinette.json") }
    let(:config) do
      {
        "bundles" => [
          {
            "name" => "bundle-1",
            "templates" => ["view1.html.erb"]
          }
        ]
      }
    end
    let(:bundle_file) do
      Rails.root.join("app", "assets", "javascripts", "antoinette", "bundle-1.js")
    end
    let(:clearer) { instance_double(Antoinette::ClearScriptTag) }

    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(config_path).and_return(config.to_json)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(bundle_file).and_return(true)
      allow(File).to receive(:delete)
      allow(Antoinette::ClearScriptTag).to receive(:new).and_return(clearer)
      allow(clearer).to receive(:clear)
    end

    it "reads config file" do
      command.call
      expect(File).to have_received(:read).with(config_path)
    end

    it "checks if bundle file exists" do
      command.call
      expect(File).to have_received(:exist?).with(bundle_file)
    end

    it "deletes bundle file when it exists" do
      command.call
      expect(File).to have_received(:delete).with(bundle_file)
    end

    it "calls ClearScriptTag for each template" do
      command.call
      expect(clearer).to have_received(:clear).with(template_path: "view1.html.erb")
    end

    context "when bundle file does not exist" do
      before do
        allow(File).to receive(:exist?).with(bundle_file).and_return(false)
      end

      it "does not delete bundle file" do
        command.call
        expect(File).not_to have_received(:delete)
      end
    end
  end

  describe Antoinette::CLI::Commands::Update do
    let(:command) { described_class.new }
    let(:elm_files) { ["app/client/App1.elm", "app/client/App2.elm"] }
    let(:config_path) { Rails.root.join("config", "antoinette.json") }
    let(:config) do
      {
        "bundles" => [
          {
            "name" => "bundle-1",
            "elm_apps" => ["App1", "App3"],
            "templates" => ["view1.html.erb"]
          },
          {
            "name" => "bundle-2",
            "elm_apps" => ["App2"],
            "templates" => ["view2.html.erb"]
          },
          {
            "name" => "bundle-3",
            "elm_apps" => ["App4"],
            "templates" => ["view3.html.erb"]
          }
        ]
      }
    end
    let(:compiler) { instance_double(Antoinette::CompileElm) }
    let(:concatenator) { instance_double(Antoinette::ConcatBundle) }
    let(:injector) { instance_double(Antoinette::InjectScriptTag) }
    let(:elm_js) { "// compiled elm" }

    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(config_path).and_return(config.to_json)
      allow(Antoinette::CompileElm).to receive(:new).and_return(compiler)
      allow(Antoinette::ConcatBundle).to receive(:new).and_return(concatenator)
      allow(Antoinette::InjectScriptTag).to receive(:new).and_return(injector)
      allow(compiler).to receive(:compile).and_return(elm_js)
      allow(concatenator).to receive(:concatenate)
      allow(injector).to receive(:inject)
    end

    it "extracts app names from elm_files" do
      command.call(elm_files: elm_files)
      expect(compiler).to have_received(:compile).with(["App1", "App3"])
      expect(compiler).to have_received(:compile).with(["App2"])
    end

    it "filters bundles by intersection with provided apps" do
      command.call(elm_files: elm_files)
      expect(compiler).to have_received(:compile).twice
    end

    it "calls CompileElm for first filtered bundle" do
      command.call(elm_files: elm_files)
      expect(compiler).to have_received(:compile).with(["App1", "App3"])
    end

    it "calls CompileElm for second filtered bundle" do
      command.call(elm_files: elm_files)
      expect(compiler).to have_received(:compile).with(["App2"])
    end

    it "calls ConcatBundle for first filtered bundle" do
      command.call(elm_files: elm_files)
      expect(concatenator).to have_received(:concatenate).with(
        bundle_name: "bundle-1",
        elm_js: elm_js
      )
    end

    it "calls ConcatBundle for second filtered bundle" do
      command.call(elm_files: elm_files)
      expect(concatenator).to have_received(:concatenate).with(
        bundle_name: "bundle-2",
        elm_js: elm_js
      )
    end

    it "calls InjectScriptTag for templates in first filtered bundle" do
      command.call(elm_files: elm_files)
      expect(injector).to have_received(:inject).with(
        template_path: "view1.html.erb",
        bundle_name: "bundle-1"
      )
    end

    it "calls InjectScriptTag for templates in second filtered bundle" do
      command.call(elm_files: elm_files)
      expect(injector).to have_received(:inject).with(
        template_path: "view2.html.erb",
        bundle_name: "bundle-2"
      )
    end

    it "does not process bundles without matching apps" do
      command.call(elm_files: elm_files)
      expect(compiler).not_to have_received(:compile).with(["App4"])
    end

    context "when no matching bundles found" do
      let(:elm_files) { ["app/client/App5.elm"] }

      it "exits with message" do
        expect { command.call(elm_files: elm_files) }.to raise_error(SystemExit)
      end
    end
  end
end
