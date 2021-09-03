require "spec-kemal"
require "spec"
require "../src/granite-api"

Granite::Connections << Granite::Adapter::Sqlite.new(name: "sqlite", url: "sqlite3://./spec/data.db")

require "../spec/fixtures/*"

def gen_routes
  Granite::Api.crud_routes(TestModel)
  Granite::Api.crud_routes(DeckCard)
end

gen_routes
