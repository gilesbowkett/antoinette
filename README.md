# Antoinette

Antoinette is a simple, lightweight build system that weaves Elm apps into JavaScript bundles for Rails templates. It ensures each page only downloads the Elm apps it actually uses, minimizing HTTP requests.

The name references "mansion weave" (a French woodworking technique used in French mansions starting around the 16th century). Elm apps are woven into JS bundles, which are then woven into Rails views.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "antoinette"
```

Run the installer:

```bash
bin/rails generate antoinette:install
```

This creates:
- `config/antoinette.json` - Bundle configuration
- `app/client/` - Directory for Elm source files
- `app/client/BundleGraph.elm` and `app/client/Sankey.elm` - Admin visualization
- `bin/compile_elm_bundle.sh` - Elm compilation script
- `bin/antoinette` - CLI binstub
- `app/assets/javascripts/antoinette/` - Bundle output directory
- Routes for `/antoinette` admin page (requires admin user)

## Usage

### Configuration

Generate bundle configuration by analyzing which Elm apps are used in your Rails views:

```bash
bin/antoinette config
```

To include custom view directories (outside `app/views/`):

```bash
bin/antoinette config --custom_views app/content/layouts/
```

### Building

Compile all Elm bundles and inject script tags into templates:

```bash
bin/antoinette build
```

### Updating Specific Apps

Rebuild only bundles containing specific Elm apps (useful during development):

```bash
bin/antoinette update app/client/SearchForm.elm app/client/CaseBuilder.elm
```

### Clearing

Remove all generated bundles and script tags:

```bash
bin/antoinette clear
```

### Admin Dashboard

Visit `/antoinette` (admin-only) to see an interactive Sankey diagram showing how Elm apps flow into bundles and then into Rails templates.

## How It Works

1. **Analysis**: Scans Rails views for `Elm.AppName.init` patterns
2. **Grouping**: Groups templates that use the same combination of Elm apps
3. **Bundling**: Compiles each group into a single JavaScript bundle (with a haiku-styled name like `holy-waterfall-8432`)
4. **Injection**: Adds `javascript_include_tag` to templates with SHA1 digest comments for idempotent updates

### Script Tag Format

Antoinette injects script tags like:

```erb
<%= javascript_include_tag "antoinette/holy-waterfall-8432" %> <!-- antoinette a1b2c3d4... -->
```

The digest comment ensures tags are only updated when bundle content changes.

## Requirements

- Rails 7.0+
- Elm compiler (`./bin/elm` or customize `bin/compile_elm_bundle.sh`)
- Node.js with uglifyjs (for production builds)

## Configuration

The `config/antoinette.json` file structure:

```json
{
  "bundles": [
    {
      "name": "holy-waterfall-8432",
      "elm_apps": ["CaseBuilder", "SearchForm"],
      "templates": ["app/views/cases/new.html.erb"]
    }
  ],
  "custom_view_paths": ["app/content/layouts/"]
}
```

## Rake Integration

The `antoinette:build` task runs automatically before `assets:precompile`:

```bash
rake antoinette:build
rake assets:precompile  # runs antoinette:build first
```

## TODO

Future improvements to consider:

- [ ] `config/initializers/antoinette.rb` for configuration options:
  - Custom Elm source path (default: `app/client/`)
  - Custom assets output path (default: `app/assets/javascripts/antoinette/`)
  - Custom views path (default: `app/views/`)
  - Configurable Elm compiler path
- [ ] Remove hard-coded Devise admin authentication in generated routes
- [ ] Support for other authentication systems
- [ ] Optional integration with importmap-rails
- [ ] Watch mode for development

## License

MIT
