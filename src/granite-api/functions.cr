module Granite::Api
  def not_found_resp(env, msg)
    env.response.status_code = 404
    env.response.content_type = "application/json"
    env.response.print(set_content_length({code: 404, message: msg}.to_json, env))
    env.response.close
  end

  def resp_204(env)
    env.response.status_code = 204
    env.response.close
  end

  macro resp_400(env, msg)
    {{env}}.response.status_code = 400
    {{env}}.response.content_type = "application/json"
    halt {{env}}, status_code: 400, response: ({code: 400, message: {{msg}}}.to_json)
  end

  def set_content_length(resp, env)
    resp = "{}" if resp.nil?
    env.response.content_length = resp.bytesize
    resp
  end

  def response_data(limit, offset, data, total)
    {
      limit:  limit,
      offset: offset,
      size:   data.size,
      total:  total,
      data:   data,
    }
  end

  def limit_offset_args(env)
    limit = env.params.query["limit"]?.nil? ? DEFAULT_LIMIT : env.params.query["limit"].to_i
    offset = env.params.query["offset"]?.nil? ? 0 : env.params.query["offset"].to_i

    {limit, offset}
  end

  def sort_args(env)
    sort_by = env.params.query["sort_by"]?.nil? ? Array(String).new : env.params.query["sort_by"].split(",")
    sort_order = env.params.query["sort_order"]?.nil? ? "asc" : env.params.query["sort_order"]
    {sort_by, sort_order}
  end

  def order_by_args(env)
    order_by = env.params.query["order_by"]?.nil? ? nil : env.params.query["order_by"]
    if order_by.nil?
      Array(String).new
    else
      order_by.split(',')
    end
  end

  private def string_to_operator(str)
    {% begin %}
    case str
    {% for op in [:eq, :gteq, :lteq, :neq, :gt, :lt, :nlt, :ngt, :ltgt, :in, :nin, :like, :nlike] %}
    when "{{op.id}}", "{{op}}", {{op}}
      {{op}}
    {% end %}
    else
      raise "unknown filter operator #{str}"
    end
    {% end %}
  end

  def param_args(env, filter_params : Array(Open::Api::Parameter)) : Array(ParamFilter)
    result = Array(ParamFilter).new

    filter_params.each do |param|
      val = param_filter(param, env)
      unless val.nil?
        result << val
      end
    end
    result
  end

  # Fetch the value from the http request
  def param_value(param : Open::Api::Parameter, env)
    case param.parameter_in
    when "query"
      env.params.query[param.name]?.nil? ? nil : env.params.query[param.name]
    when "path"
      env.params.url[param.name]?.nil? ? nil : env.params.url[param.name]
    when "header"
      env.response.headers[param.name]?.nil? ? nil : env.response.headers[param.name]
    when "body"
      if env.response.headers["Content-Type"] == "application/json"
        env.params.json[param.name]?.nil? ? nil : env.params.json[param.name]
      else
        env.params.body[param.name]?.nil? ? nil : env.params.body[param.name].as(String)
      end
    else
      nil
    end
  end

  # Convert the `Open::Api::Parameter` to a filter struct
  private def param_filter(param : Open::Api::Parameter, env) : ParamFilter?
    param_name = param.name
    op = :eq
    param_value = param_value(param, env)
    return nil if param_value.nil?

    if param_name =~ /^(.*)_(:\w+)$/
      param_name = $1
      op = string_to_operator($2)
    end

    case param_value
    when String
      if op == :in || op == :nin
        param_value = param_value.split(',')
      elsif op == :like || op == :nlike
        param_value = "%#{param_value}%"
      end
      {name: param_name, op: op, value: param_value}
    when Bool, Float64, Int64
      {name: param_name, op: op, value: param_value}
    else
      nil
    end
  end

  # Create a schema object for a list return
  def create_list_schemas(ref_name)
    items_schema = Open::Api::Schema.new(
      schema_type: "array",
      items: Open::Api::Ref.new("#/components/schemas/#{ref_name}")
    )

    resp_list_object_name = "#{ref_name}_resp_list"
    resp_list_object = Open::Api::Schema.new(
      schema_type: "object",
      required: [
        "limit",
        "offset",
        "size",
        "total",
        "items",
      ],
      properties: Hash(String, Open::Api::SchemaRef){
        "limit"  => Open::Api::Schema.new("integer", default: 0),
        "offset" => Open::Api::Schema.new("integer", default: 0),
        "size"   => Open::Api::Schema.new("integer", default: 0),
        "total"  => Open::Api::Schema.new("integer", default: 0),
        "items"  => items_schema,
      },
      example: Hash(String, Open::Api::ExampleValue){
        "limit"  => 0,
        "offset" => 0,
        "size"   => 0,
        "total"  => 0,
        "items"  => Array(Open::Api::ExampleValue).new,
      }
    )

    {resp_list_object_name, resp_list_object}
  end

  def create_patch_body_schemas(model_def) : Open::Api::Schema
    params = model_def.body_params
    properties = model_def.properties.select { |k, v| k != "created_at" && k != "created_at" && k != model_def.primary_key }

    Open::Api::Schema.new(
      schema_type: "object",
      required: params.select(&.required).map(&.name),
      properties: properties,
    )
  end

  def list_req_params
    [
      SWAGGER_API.parameter_ref("resp_limit"),
      SWAGGER_API.parameter_ref("resp_offset"),
      SWAGGER_API.parameter_ref("resp_sort_by"),
      SWAGGER_API.parameter_ref("resp_sort_order"),
    ]
  end

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

  def default_response_refs
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
  private def register_spoved_defaults
    # Schemas
    register_default_schemas
    # Parameters
    register_default_parameters
    # Responses
    register_default_responses
  end

  # Create `Open::Api::Parameter` for the provided column type
  def filter_params_for_var(name, type, **args) : Array(Open::Api::Parameter)
    params = [] of Open::Api::Parameter
    params << Open::Api::Parameter.new(name, type, **args, description: "return results that match #{name}")

    case Open::Api.get_open_api_type(type)
    when "string"
      case type
      when UUID.class, (UUID | Nil).class
        # Provide specific operators for UUIDs
        Granite::Api::UUID_OPERATORS.each do |op|
          params << Open::Api::Parameter.new(name + "_#{op}", type, **args, description: "return results that are #{op} #{name}")
        end
      else
        Granite::Api::STRING_OPERATORS.each do |op|
          params << Open::Api::Parameter.new(name + "_#{op}", type, **args, description: "return results that are #{op} #{name}")
        end
      end
    when "integer"
      Granite::Api::NUM_OPERATORS.each do |op|
        params << Open::Api::Parameter.new(name + "_#{op}", type, **args, description: "return results that are #{op} #{name}")
      end
    end
    params
  end

  def create_get_list_op_item(model_name, params, resp_ref, operation_id : String? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Returns list of #{model_name}").tap do |op|
      op.operation_id = operation_id.nil? ? "get_#{model_name}_list" : operation_id
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("List of #{model_name}").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: resp_ref),
          }
        end,
      }.merge(default_response_refs)
    end
  end

  def create_get_op_item(model_name, params, resp_ref, operation_id : String? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Returns record of a specified #{model_name}").tap do |op|
      op.operation_id = operation_id.nil? ? "get_#{model_name}_by_id" : operation_id
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("#{model_name} record").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: resp_ref),
          }
        end,
      }.merge(default_response_refs)
    end
  end

  # Create a new delete `Open::Api::OperationItem` for a model
  def create_delete_op_item(model_name, params) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Delete the specified #{model_name}").tap do |op|
      op.operation_id = "delete_#{model_name}_by_id"
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "204" => SWAGGER_API.response_ref("204"),
      }.merge(default_response_refs)
    end
  end

  # Create a new create `Open::Api::OperationItem` for a model
  def create_put_op_item(model_name, model_ref, body_schema : Open::Api::Schema) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Create new #{model_name} record").tap do |op|
      op.operation_id = "create_#{model_name}"
      op.tags << model_name
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("create new #{model_name} record").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: model_ref),
          }
        end,
      }.merge(default_response_refs)
      op.request_body = Open::Api::RequestBody.new(
        description: "#{model_name} object",
        content: {
          "application/json" => Open::Api::MediaType.new(schema: body_schema),
        },
        required: true,
      )
    end
  end

  def create_patch_op_item(model_name, params, body_object, model_ref) : Open::Api::OperationItem
    Open::Api::OperationItem.new("Update the specified #{model_name}").tap do |op|
      op.operation_id = "update_#{model_name}_by_id"
      op.tags << model_name
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new("update the specified #{model_name}").tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: model_ref),
          }
        end,
      }.merge(default_response_refs)
      op.request_body = Open::Api::RequestBody.new(
        description: "#{model_name} object",
        content: {
          "application/json" => Open::Api::MediaType.new(schema: body_object),
        },
        required: true,
      )
    end
  end

  def register_schema(_model, model_def)
    if !model_def.open_api.has_schema_ref?(model_def.name)
      Log.info { "Register schema: #{_model}" }

      object = Open::Api::Schema.new(
        schema_type: "object",
        required: [
          model_def.primary_key,
        ],
        properties: model_def.properties
      )

      model_def.open_api.register_schema(model_def.name, object)
    end
  end
end
