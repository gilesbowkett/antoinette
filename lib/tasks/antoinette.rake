# frozen_string_literal: true

namespace :antoinette do
  desc "Build JavaScript bundles from Elm apps"
  task build: :environment do
    Antoinette::CLI::Commands::Build.new.call
  end
end

Rake::Task["assets:precompile"].enhance(["antoinette:build"])
