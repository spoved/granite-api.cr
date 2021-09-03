module Granite::Api
  private def register_default_schemas
    SWAGGER_API.register_schema("error", Open::Api::Schema.new(
      schema_type: "object",
      properties: Hash(String, Open::Api::SchemaRef){
        "code"    => Open::Api::Schema.new("integer", format: "int32"),
        "message" => Open::Api::Schema.new("string"),
      },
    ))
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
      "resp_sort_by" => Open::Api::Parameter.new(
        "sort_by", String?, location: "query",
        description: "sort the results returned by provided field.",
        required: false, default_value: nil
      ),
      "resp_sort_order" => Open::Api::Parameter.new(
        "sort_order", String?, location: "query",
        description: "sort the results returned in the provided order (asc, desc).",
        required: false, default_value: nil
      ),
    }.each do |name, param|
      SWAGGER_API.register_parameter name, param
    end
  end

  private def register_default_responses
    error_content = {
      "application/json" => Open::Api::MediaType.new(SWAGGER_API.schema_ref("error")),
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
      SWAGGER_API.register_response(code, response)
    end
  end

  private def default_response_refs
    {
      "400"     => SWAGGER_API.response_ref("400"),
      "401"     => SWAGGER_API.response_ref("401"),
      "403"     => SWAGGER_API.response_ref("403"),
      "404"     => SWAGGER_API.response_ref("404"),
      "500"     => SWAGGER_API.response_ref("500"),
      "default" => SWAGGER_API.response_ref("default"),
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
