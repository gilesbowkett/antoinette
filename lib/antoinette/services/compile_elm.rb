# frozen_string_literal: true

module Antoinette
  class CompileElm
    def initialize(environment: Rails.env.to_s)
      @environment = environment
    end

    def compile(elm_app_names)
      elm_file_paths = elm_app_names.map { |name| "app/client/#{name}.elm" }
      output_file = "tmp/elm_compiled.js"

      script_path = Rails.root.join("bin", "compile_elm_bundle.sh")
      command = "#{script_path} #{@environment} #{output_file} #{elm_file_paths.join(" ")}"

      system(command)

      unless Process.last_status.success?
        raise "Elm compilation failed"
      end

      File.read(output_file)
    ensure
      File.delete(output_file) if output_file && File.exist?(output_file)
    end
  end
end
