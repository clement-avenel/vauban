# Be sure to restart your server when you modify this file.

# Rails 8.1 uses Propshaft by default instead of Sprockets
# Only configure assets if Sprockets is being used
if Rails.application.config.respond_to?(:assets)
  # Version of your assets, change this if you want to expire all your assets.
  Rails.application.config.assets.version = "1.0"

  # Add additional assets to the asset load path.
  # Rails.application.config.assets.paths << Emoji.images_path
end
