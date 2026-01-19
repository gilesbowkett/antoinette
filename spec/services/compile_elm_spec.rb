# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::CompileElm do
  let(:compiler) { described_class.new(environment: environment) }
  let(:environment) { "development" }
  let(:elm_app_names) { ["CaseBuilder"] }

  describe "#compile" do
    let(:compiled_js) { "// compiled elm code" }
    let(:output_file) { "tmp/elm_compiled.js" }

    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(output_file).and_return(compiled_js)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(output_file).and_return(true)
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(output_file)
    end

    context "when compilation succeeds" do
      let(:result) { compiler.compile(elm_app_names) }
      let(:success_status) { instance_double(Process::Status, success?: true) }

      before do
        allow(compiler).to receive(:system).and_return(true)
        allow(Process).to receive(:last_status).and_return(success_status)
      end

      it "returns compiled JavaScript" do
        expect(result).to eq(compiled_js)
      end

      it "calls shell script with environment" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with(/compile_elm_bundle\.sh development/)
      end

      it "calls shell script with output file" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with(/tmp\/elm_compiled\.js/)
      end

      it "calls shell script with elm file paths" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with(/app\/client\/CaseBuilder\.elm/)
      end

      it "cleans up temporary file" do
        compiler.compile(elm_app_names)
        expect(File).to have_received(:delete).with(output_file)
      end
    end

    context "when compilation fails" do
      let(:failure_status) { instance_double(Process::Status, success?: false) }

      before do
        allow(compiler).to receive(:system).and_return(true)
        allow(Process).to receive(:last_status).and_return(failure_status)
      end

      it "raises error" do
        expect { compiler.compile(elm_app_names) }.to raise_error("Elm compilation failed")
      end

      it "cleans up temporary file" do
        begin
          compiler.compile(elm_app_names)
        rescue
        end
        expect(File).to have_received(:delete).with(output_file)
      end
    end

    context "when multiple elm apps provided" do
      let(:elm_app_names) { ["CaseBuilder", "SearchForm"] }
      let(:success_status) { instance_double(Process::Status, success?: true) }

      before do
        allow(compiler).to receive(:system).and_return(true)
        allow(Process).to receive(:last_status).and_return(success_status)
      end

      it "includes all elm file paths in command" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with(/app\/client\/CaseBuilder\.elm/)
      end

      it "includes second elm file path in command" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with(/app\/client\/SearchForm\.elm/)
      end
    end

    context "when environment is production" do
      let(:environment) { "production" }
      let(:success_status) { instance_double(Process::Status, success?: true) }

      before do
        allow(compiler).to receive(:system).and_return(true)
        allow(Process).to receive(:last_status).and_return(success_status)
      end

      it "calls shell script with production environment" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with(/compile_elm_bundle\.sh production/)
      end
    end
  end
end
