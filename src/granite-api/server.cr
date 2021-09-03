module Granite::Api
  def init_server(name : String? = nil, host : String? = nil)
    open_api.info.title = "Mtg Helper API" if name

    if host
      open_api.servers << Open::Api::Server.new(host)
    end

    error 404 do |env|
      Granite::Api.not_found_resp(env, "Nothin here, sorry.")
    end

    add_handler Granite::Api::CorsHandler.new
    Kemal.config.logger = Granite::Api::Logger.new

    before_all "/api/*" do |env|
      env.response.content_type = "application/json"
    end

    default_routes
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
    Granite::Api::ROUTES << [ {{typ}}, {{path}}, {{model ? model.stringify : ""}} ]
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
