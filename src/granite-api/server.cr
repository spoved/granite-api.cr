module Granite::Api
  macro init_server
    Granite::Api.register_route("OPTIONS", "/*",
      summary: "CORS Options Return",
      schema: Open::Api::Schema.new("object",
        required: ["msg"],
        properties: Hash(String, Open::Api::SchemaRef){"msg" => Open::Api::Schema.new("string")})
    )
    options "/*" do
      # TODO: what should OPTIONS requests actually respond with?
      {msg: "ok"}.to_json
    end

    add_handler Spoved::Kemal::CorsHandler.new
    Kemal.config.logger = Granite::Api::Logger.new
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

  macro register_route(typ, path, model = nil, op_item = nil, summary = nil, schema = nil)
    Log.info { "registring route: " + {{path}} }
    Granite::Api::SPOVED_ROUTES << [ {{typ}}, {{path}}, {{model ? model.stringify : ""}} ]
    %summary = {{summary}}
    %schema = {{schema}}
    %op_item = {{op_item}}

    if %op_item.nil? && %summary.is_a?(String) && %schema.is_a?(Open::Api::Schema)
      %op_item = Open::Api::OperationItem.new(%summary).tap do |op|
        op.responses["200"] = Open::Api::Response.new(%summary).tap do |resp|
          resp.content = {
            "application/json" => Open::Api::MediaType.new(schema: %schema),
          }
        end
      end
    end

    if %op_item.is_a?(Open::Api::OperationItem)
      Granite::Api.open_api.add_path({{path}}, Open::Api::Operation.parse({{typ}}), %op_item)
    end
  end
end
