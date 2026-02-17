# frozen_string_literal: true

require "rails_helper"

RSpec.describe Antoinette::LayoutResolver do
  let(:layout_dirs) { ["app/views/layouts"] }
  let(:default_layout) { "application" }
  let(:resolver) { described_class.new(layout_dirs: layout_dirs, default_layout: default_layout) }

  describe "#layout_apps_map" do
    let(:layout_dir) { Rails.root.join("app", "views", "layouts") }
    let(:layout_files) { [layout_dir.join("application.html.erb").to_s] }
    let(:layout_content) do
      <<~ERB
        <nav>
          <script>const app = Elm.NavSidebar.init({ node: document.getElementById("nav") })</script>
        </nav>
        <%= yield %>
      ERB
    end

    before do
      allow(Dir).to receive(:glob)
        .with(Rails.root.join("app/views/layouts", "*.html.erb"))
        .and_return(layout_files)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(layout_files.first).and_return(layout_content)
    end

    it "returns a hash keyed by layout name" do
      expect(resolver.layout_apps_map).to have_key("application")
    end

    it "extracts Elm app names from layout files" do
      expect(resolver.layout_apps_map["application"]).to eq(["NavSidebar"])
    end

    context "with multiple layout dirs" do
      let(:layout_dirs) { ["app/views/layouts", "app/content/layouts"] }
      let(:blog_layout_dir) { Rails.root.join("app", "content", "layouts") }
      let(:blog_layout_file) { blog_layout_dir.join("blog.html.erb").to_s }
      let(:blog_layout_content) do
        <<~ERB
          <nav>
            <script>const app = Elm.NavSidebar.init({ node: document.getElementById("nav") })</script>
          </nav>
          <%= yield %>
        ERB
      end

      before do
        allow(Dir).to receive(:glob)
          .with(Rails.root.join("app/content/layouts", "*.html.erb"))
          .and_return([blog_layout_file])
        allow(File).to receive(:read).with(blog_layout_file).and_return(blog_layout_content)
      end

      it "includes layouts from all dirs" do
        expect(resolver.layout_apps_map.keys).to contain_exactly("application", "blog")
      end

      it "extracts apps from blog layout" do
        expect(resolver.layout_apps_map["blog"]).to eq(["NavSidebar"])
      end
    end

    context "with layout containing no Elm apps" do
      let(:layout_content) { "<html><body><%= yield %></body></html>" }

      it "returns empty array for that layout" do
        expect(resolver.layout_apps_map["application"]).to eq([])
      end
    end

    context "with layout containing multiple Elm apps" do
      let(:layout_content) do
        <<~ERB
          <script>
            Elm.NavSidebar.init({ node: document.getElementById("nav") })
            Elm.Footer.init({ node: document.getElementById("footer") })
          </script>
          <%= yield %>
        ERB
      end

      it "extracts all app names" do
        expect(resolver.layout_apps_map["application"]).to contain_exactly("NavSidebar", "Footer")
      end
    end
  end

  describe "#layout_for" do
    let(:template_path) { "app/content/pages/blog/index.html.erb" }
    let(:full_path) { Rails.root.join(template_path).to_s }

    before do
      allow(File).to receive(:exist?).and_call_original
    end

    context "when template has frontmatter with layout key" do
      before do
        allow(File).to receive(:exist?).with(full_path).and_return(true)
        allow(File).to receive(:read).with(full_path).and_return(<<~ERB)
          ---
          layout: blog
          title: My Blog
          ---
          <h1>Blog</h1>
        ERB
      end

      it "returns the layout name from frontmatter" do
        expect(resolver.layout_for(template_path)).to eq("blog")
      end
    end

    context "when template has frontmatter without layout key" do
      before do
        allow(File).to receive(:exist?).with(full_path).and_return(true)
        allow(File).to receive(:read).with(full_path).and_return(<<~ERB)
          ---
          title: My Page
          ---
          <h1>Page</h1>
        ERB
      end

      it "returns the default layout" do
        expect(resolver.layout_for(template_path)).to eq("application")
      end
    end

    context "when template has no frontmatter" do
      before do
        allow(File).to receive(:exist?).with(full_path).and_return(true)
        allow(File).to receive(:read).with(full_path).and_return("<h1>Regular view</h1>")
      end

      it "returns the default layout" do
        expect(resolver.layout_for(template_path)).to eq("application")
      end
    end

    context "when template file does not exist" do
      before do
        allow(File).to receive(:exist?).with(full_path).and_return(false)
      end

      it "returns the default layout" do
        expect(resolver.layout_for(template_path)).to eq("application")
      end
    end
  end

  describe "#apps_for" do
    let(:template_path) { "app/content/pages/blog/index.html.erb" }

    before do
      allow(resolver).to receive(:layout_for).with(template_path).and_return("blog")
      allow(resolver).to receive(:layout_apps_map).and_return({
        "application" => ["NavSidebar"],
        "blog" => ["NavSidebar", "BlogWidget"]
      })
    end

    it "returns layout apps for the template's layout" do
      expect(resolver.apps_for(template_path)).to eq(["NavSidebar", "BlogWidget"])
    end

    context "when layout has no apps" do
      before do
        allow(resolver).to receive(:layout_for).with(template_path).and_return("minimal")
      end

      it "returns empty array" do
        expect(resolver.apps_for(template_path)).to eq([])
      end
    end
  end
end
