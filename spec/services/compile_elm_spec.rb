# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::CompileElm do
  let(:compiler) { described_class.new(environment: environment) }
  let(:environment) { "development" }
  let(:elm_app_names) { ["CaseBuilder"] }

  describe "#compile" do
    let(:compiled_js) { "// compiled elm code" }
    let(:minified_js) { "// minified" }
    let(:output_file) { "tmp/elm_compiled.js" }
    let(:success_status) { instance_double(Process::Status, success?: true) }

    before do
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(output_file).and_return(compiled_js)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(output_file).and_return(true)
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(output_file)
      allow(compiler).to receive(:system).and_return(true)
      allow(Process).to receive(:last_status).and_return(success_status)
    end

    context "when compilation succeeds in development" do
      let(:result) { compiler.compile(elm_app_names) }

      it "returns compiled JavaScript" do
        expect(result).to eq(compiled_js)
      end

      it "calls elm make without optimize flag" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with("elm make --output=tmp/elm_compiled.js app/client/CaseBuilder.elm")
      end

      it "cleans up temporary file" do
        compiler.compile(elm_app_names)
        expect(File).to have_received(:delete).with(output_file)
      end
    end

    context "when compilation fails" do
      let(:failure_status) { instance_double(Process::Status, success?: false) }

      before do
        allow(Process).to receive(:last_status).and_return(failure_status)
      end

      it "raises error" do
        expect { compiler.compile(elm_app_names) }.to raise_error("Elm compilation failed")
      end

      it "cleans up temporary file" do
        compiler.compile(elm_app_names) rescue nil
        expect(File).to have_received(:delete).with(output_file)
      end
    end

    context "when multiple elm apps provided" do
      let(:elm_app_names) { ["CaseBuilder", "SearchForm"] }

      it "includes all elm file paths in command" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with("elm make --output=tmp/elm_compiled.js app/client/CaseBuilder.elm app/client/SearchForm.elm")
      end
    end

    context "when environment is production" do
      let(:environment) { "production" }

      before do
        allow(Uglifier).to receive(:compile).and_return(minified_js)
      end

      it "calls elm make with optimize flag" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with("elm make --optimize --output=tmp/elm_compiled.js app/client/CaseBuilder.elm")
      end

      it "minifies the output" do
        compiler.compile(elm_app_names)
        expect(Uglifier).to have_received(:compile).with(
          compiled_js,
          hash_including(
            compress: hash_including(
              pure_funcs: %w[F2 F3 F4 F5 F6 F7 F8 F9 A2 A3 A4 A5 A6 A7 A8 A9],
              pure_getters: true
            ),
            mangle: true
          )
        )
      end

      it "returns minified JavaScript" do
        expect(compiler.compile(elm_app_names)).to eq(minified_js)
      end
    end

    context "with custom elm_path" do
      let(:compiler) { described_class.new(elm_path: "./bin/elm", environment: environment) }

      it "uses custom elm path" do
        compiler.compile(elm_app_names)
        expect(compiler).to have_received(:system)
          .with("./bin/elm make --output=tmp/elm_compiled.js app/client/CaseBuilder.elm")
      end
    end
  end
end
