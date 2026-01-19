# frozen_string_literal: true

module Antoinette
  class GraphController < ::ApplicationController
    def show
      @bundle_graph = File.read(Rails.root.join("config/antoinette.json"))
    end
  end
end
