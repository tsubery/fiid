require "graphql/client"
require "graphql/client/http"

module Podchaser
  HTTP = GraphQL::Client::HTTP.new("https://api.podchaser.com/graphql") do
    def headers(_context)
      token = if Rails.env.production?
                ENV.fetch('PODCHASER_PROD_TOKEN')
              else
                ENV.fetch('PODCHASER_DEV_TOKEN')
              end

      {
        "Authorization" => "Bearer #{token}",
        "Content-Type" => "application/json"
      }
    end
  end

  Schema = GraphQL::Client.load_schema(
    Rails.root.join("db/podchaser_schema.json").to_s
  )

  Client = GraphQL::Client.new(schema: Schema, execute: HTTP)
end
