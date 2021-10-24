module Granite::Api
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

  def create_get_list_op_item(model_name, params, resp_ref, operation_id : String? = nil,
                              security : Array(Open::Api::Security::Requirement)? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new(
      summary: "Returns list of #{model_name}",
      operation_id: operation_id.nil? ? "get_#{model_name}_list" : operation_id,
      tags: [model_name],
      security: security,
    ).tap do |op|
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

  def create_get_op_item(model_name, params, resp_ref, operation_id : String? = nil,
                         security : Array(Open::Api::Security::Requirement)? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new(
      summary: "Returns record of a specified #{model_name}",
      operation_id: operation_id.nil? ? "get_#{model_name}_by_id" : operation_id,
      tags: [model_name],
      security: security,
    ).tap do |op|
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
  def create_delete_op_item(model_name, params,
                            security : Array(Open::Api::Security::Requirement)? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new(
      summary: "Delete the specified #{model_name}",
      operation_id: "delete_#{model_name}_by_id",
      tags: [model_name],
      security: security,
    ).tap do |op|
      op.parameters.concat params
      op.responses = Open::Api::OperationItem::Responses{
        "204" => OPEN_API.response_ref("204"),
      }.merge(default_response_refs)
    end
  end

  # Create a new create `Open::Api::OperationItem` for a model
  def create_put_op_item(model_name, model_ref, body_schema : Open::Api::SchemaRef,
                         security : Array(Open::Api::Security::Requirement)? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new(
      summary: "Create new #{model_name} record",
      operation_id: "create_#{model_name}",
      tags: [model_name],
      security: security,
    ).tap do |op|
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

  def create_post_op_item(model_name : String, resp_ref : Open::Api::SchemaRef, body_schema : Open::Api::SchemaRef,
                          params : Array(Open::Api::Parameter | Open::Api::Ref),
                          security : Array(Open::Api::Security::Requirement)? = nil,
                          summary : String? = nil, operation_id : String? = nil) : Open::Api::OperationItem
    summary ||= "Create new #{model_name} record"
    operation_id ||= "create_#{model_name}"

    Open::Api::OperationItem.new(
      summary: summary,
      operation_id: operation_id,
      tags: [model_name],
      security: security,
    ).tap do |op|
      op.parameters.concat params

      op.responses = Open::Api::OperationItem::Responses{
        "200" => Open::Api::Response.new(summary).tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: resp_ref),
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

  def create_patch_op_item(model_name, params, body_object, model_ref,
                           security : Array(Open::Api::Security::Requirement)? = nil) : Open::Api::OperationItem
    Open::Api::OperationItem.new(
      summary: "Update the specified #{model_name}",
      operation_id: "update_#{model_name}_by_id",
      tags: [model_name],
      security: security,
    ).tap do |op|
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

  macro body_schema(_model)
    Open::Api::Schema.new("object").tap do |schema|
      {% model = _model.resolve %}
      {% columns = [] of MetaVar %}
      {% enum_check = {} of StringLiteral => BoolLiteral %}
      {% for var in model.instance_vars %}
        {% if var.annotation(Granite::Column) %}
          {% enum_check[var.id] = var.type.union_types.first < Enum %}
          {% if var.id == :created_at || var.id == :modified_at %}
            # skip created_at/modified_at
          {% else %}
            {% columns << var %}
          {% end %}
        {% end %}
      {% end %}
      schema.properties = Hash(String, Open::Api::SchemaRef){
        {% for column in columns %}
        {{column.id.stringify}} => Open::Api::Schema.new(
          {% if column.annotation(Granite::Api::Formatter) && column.annotation(Granite::Api::Formatter)[:type] == :json %}
          schema_type: "object",
          {% elsif enum_check[column.id] %}
          schema_type: "string", format: "string", default: {{column.default_value}}.to_s,
          {% else %}
          schema_type: Open::Api.get_open_api_type({{column.type}}),
          format: Open::Api.get_open_api_format({{column.type}}),
          default: {{column.default_value}}
          {% end %}
        ),
        {% end %}
      }
    end
  end
end
