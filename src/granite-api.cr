require "granite"
require "open-api"
require "kemal"
require "tablo"

require "spoved/logger"
require "spoved/ext/string"

require "uuid/json"
require "./ext/*"

module Granite::Api
  extend self

  SPOVED_ROUTES = Array(Array(String)).new
  SWAGGER_API   = Open::Api.new
  # :nodoc:
  DEFAULT_LIMIT = 100
  # :nodoc:
  NUM_OPERATORS = %w(:neq :in :nin :gteq :lteq :gt :lt :nlt :ngt :ltgt)
  # :nodoc:
  STRING_OPERATORS = %w(:neq :in :nin :like :nlike)
  # :nodoc:
  UUID_OPERATORS = %w(:neq :in :nin)

  def open_api : Open::Api
    SWAGGER_API
  end

  register_spoved_defaults

  # Print the registered routes into a table
  def print_routes
    resources = Granite::Api::SPOVED_ROUTES.map(&.last).uniq!.sort
    resources.each do |resource|
      puts resource

      data = Granite::Api::SPOVED_ROUTES.select(&.last.==(resource))
      table = Tablo::Table.new(data, connectors: Tablo::CONNECTORS_SINGLE_DOUBLE) do |t|
        t.add_column("Path", &.[0])
        t.add_column("Route", &.[1])
      end

      table.shrinkwrap!
      puts table
      puts ""
    end
  end
end

require "./granite-api/**"
