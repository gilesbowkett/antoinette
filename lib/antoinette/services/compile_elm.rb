# frozen_string_literal: true

require "uglifier"

module Antoinette
  class CompileElm
    ELM_PURE_FUNCS = %w[F2 F3 F4 F5 F6 F7 F8 F9 A2 A3 A4 A5 A6 A7 A8 A9].freeze

    def initialize(elm_path: "elm", environment: Rails.env.to_s)
      @elm_path = elm_path
      @environment = environment
    end

    def compile(elm_app_names)
      elm_file_paths = elm_app_names.map { |name| "app/client/#{name}.elm" }
      output_file = "tmp/elm_compiled.js"
      optimize_flag = production? ? "--optimize" : ""

      command = "#{@elm_path} make #{optimize_flag} --output=#{output_file} #{elm_file_paths.join(" ")}".squeeze(" ")

      system(command)

      unless Process.last_status.success?
        raise "Elm compilation failed"
      end

      js = File.read(output_file)
      production? ? minify(js) : js
    ensure
      File.delete(output_file) if output_file && File.exist?(output_file)
    end

    private

    def production?
      @environment == "production"
    end

    def minify(js)
      Uglifier.compile(
        js,
        compress: {
          pure_funcs: ELM_PURE_FUNCS,
          pure_getters: true,
          keep_fargs: false,
          unsafe_comps: true,
          unsafe: true
        },
        mangle: true
      )
    end
  end
end
