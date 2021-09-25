module Granite::Api
  private def default_routes
    get "/api/v1/swagger.json" do |env|
      env.response.content_type = "application/json"
      Granite::Api.set_content_length(open_api.to_json, env)
    end

    get "/api/v1/swagger.yaml" do |env|
      env.response.content_type = "application/yaml"
      Granite::Api.set_content_length(open_api.to_yaml.gsub(/^\-{3}\s+/, ""), env)
    end

    Granite::Api.register_route("OPTIONS", "/*",
      summary: "CORS Options Return",
      schema: Open::Api::Schema.new("object",
        required: ["msg"],
        properties: Hash(String, Open::Api::SchemaRef){
          "msg" => Open::Api::Schema.new("string"),
        })
    )
    options "/*" do
      # TODO: what should OPTIONS requests actually respond with?
      {msg: "ok"}.to_json
    end

    Granite::Api.register_route("GET", "/healthz",
      summary: "get health",
      schema: Open::Api::Schema.new(
        "object",
        required: ["status"],
        properties: Hash(String, Open::Api::SchemaRef){
          "status" => Open::Api::Schema.new("string"),
        }
      )
    )
    get "/healthz" do |env|
      env.response.content_type = "application/json"
      {status: "ok"}.to_json
    end
  end

  private def register_default_schemas
    OPEN_API.register_schema("error", Open::Api::Schema.new(
      schema_type: "object",
      properties: Hash(String, Open::Api::SchemaRef){
        "code"    => Open::Api::Schema.new("integer", format: "int32"),
        "message" => Open::Api::Schema.new("string"),
      },
    ))

    # FIXME: enable and move filters to this method
    OPEN_API.register_schema("filter_obj", Open::Api::Schema.from_type(Granite::Api::ParamFilter))
  end

  private def register_default_parameters
    {
      "resp_limit" => Open::Api::Parameter.new(
        "limit", Int32?, location: "query",
        description: "limit the number of results returned (default: 100)",
        required: false, default_value: DEFAULT_LIMIT
      ),
      "resp_offset" => Open::Api::Parameter.new(
        "offset", Int32?, location: "query",
        description: "offset the results returned",
        required: false, default_value: 0
      ),
      "resp_order_by" => Open::Api::Parameter.new(
        "order_by", String?, location: "query",
        description: "sort the results returned by provided field.",
        required: false, default_value: nil
      ),
      "query_filters" => Open::Api::Parameter.new(
        name: "filters", parameter_in: "query",
        schema: Open::Api::Schema.new(
          schema_type: "array",
          items: OPEN_API.schema_ref("filter_obj")
        ),
        description: "return results that match all filters",
        required: false
      ),
    }.each do |name, param|
      OPEN_API.register_parameter name, param
    end
  end

  private def register_default_responses
    error_content = {
      "application/json" => Open::Api::MediaType.new(OPEN_API.schema_ref("error")),
    }
    default_responses = {
      "204"     => Open::Api::Response.new(description: "successfully deleted record"),
      "400"     => Open::Api::Response.new(description: "Bad Request", content: error_content),
      "401"     => Open::Api::Response.new(description: "Unauthorized", content: error_content),
      "403"     => Open::Api::Response.new(description: "Forbidden", content: error_content),
      "404"     => Open::Api::Response.new(description: "Not Found", content: error_content),
      "500"     => Open::Api::Response.new(description: "Internal Server Error", content: error_content),
      "default" => Open::Api::Response.new(description: "Unknown Error", content: error_content),
    }

    default_responses.each do |code, response|
      OPEN_API.register_response(code, response)
    end
  end

  def default_response_refs
    {
      "400"     => OPEN_API.response_ref("400"),
      "401"     => OPEN_API.response_ref("401"),
      "403"     => OPEN_API.response_ref("403"),
      "404"     => OPEN_API.response_ref("404"),
      "500"     => OPEN_API.response_ref("500"),
      "default" => OPEN_API.response_ref("default"),
    }
  end

  # Create default open api definitions and references
  private def register_defaults
    # Schemas
    register_default_schemas
    # Parameters
    register_default_parameters
    # Responses
    register_default_responses
  end
end
