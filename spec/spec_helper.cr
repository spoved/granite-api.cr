ENV["KEMAL_ENV"] = "test"

require "spec"
require "spec-kemal"
require "../src/granite-api"

spoved_logger :trace, bind: true, clear: true
Granite::Connections << Granite::Adapter::Sqlite.new(name: "sqlite", url: "sqlite3://./spec/files/data.sqlite")

require "../spec/fixtures/*"

def gen_routes
  Granite::Api.crud_routes(TestModel)
  Granite::Api.crud_routes(DeckCard)
end

gen_routes

get "/" do
  "Hello World!"
end

Kemal.run
