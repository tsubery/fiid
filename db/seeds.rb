# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
class DbSeeder
  def self.run
    _spam_email_feed = IncomingEmailFeed.create!(url: IncomingEmailFeed::SPAM_EMAIL)
    _pocket_feed = Feed.create!(type: PocketFeed)
    _pocket_library = Library.create!(type: "PocketLibrary")
    _default_podcast = Library.create!(title: "Default Podcast")
  end
end

DbSeeder.run
