# frozen_string_literal: true

require_relative "lib/antoinette/version"

Gem::Specification.new do |spec|
  spec.name = "antoinette"
  spec.version = Antoinette::VERSION
  spec.authors = ["Giles Bowkett"]
  spec.email = ["gilesb@gmail.com"]

  spec.summary = "Weaves Elm apps into JavaScript bundles for Rails templates"
  spec.description = "Antoinette analyzes which Elm apps are used in Rails views, " \
                     "bundles them together, and injects script tags into templates. " \
                     "Minimizes HTTP requests while ensuring each page only loads the Elm apps it needs."
  spec.homepage = "https://github.com/gilesbowkett/antoinette"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,lib}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md"]
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "csv", "~> 3.0"
  spec.add_dependency "dry-cli", "~> 1.0"
  spec.add_dependency "haikunator", "~> 1.1"

  spec.post_install_message = <<~MSG

    Thanks for installing Antoinette!

    To complete setup, run:

      bin/rails generate antoinette:install

  MSG
end
