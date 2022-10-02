module Granite::Api
  def init_server(name : String? = nil, host : String? = nil, auth : Granite::Api::Auth? = nil)
    open_api.info.title = name if name

    if host
      open_api.servers << Open::Api::Server.new(host)
    end

    error 404 do |env|
      Granite::Api.not_found_resp(env, "Nothin here, sorry.")
    end

    if auth
      add_handler Granite::Api::TokenHandler.new(auth)
      open_api.register_security_scheme(auth.scheme_name, auth.security_scheme)
    end

    add_handler Granite::Api::CorsHandler.new
    Kemal.config.logger = Granite::Api::Logger.new

    before_all "/api/*" do |env|
      env.response.content_type = "application/json"
    end

    default_routes
  end

  def conf_auth(pub_key : String)
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
    else
      Log.warn { "Schema already registered for: #{_model}" }
    end
  end

  macro register_route(typ, path, model = nil, op_item = nil, summary = nil, schema = nil, params = nil, security = nil, tags = nil)
    Log.info { "registring route: " + {{path}} }
    Granite::Api::ROUTES << [ {{typ}}, {{path}}, {{model ? model.stringify : ""}} ]
    %summary = {{summary}}
    %schema = {{schema}}
    %op_item = {{op_item}}
    %params = {{params}}
    %security = {{security}}
    %tags = {{tags}}
    %open_api_path = {{path}}

    if %open_api_path =~ /\/:([\w\_]+)(\/|$)/
      %open_api_path = %open_api_path.split("/").map do |x|
        if x.starts_with?(':')
          "{#{x.strip(':')}}"
        else
          x
        end
      end.join('/')

      # %open_api_path = %open_api_path.gsub(/\/:([\w\_]+)(:?\/|$)/, "/{#{$1}}/").chomp('/')
      # puts %open_api_path
    end

    if %op_item.nil? && %summary.is_a?(String) && %schema.is_a?(Open::Api::SchemaRef)
      %op_item = Open::Api::OperationItem.new(%summary).tap do |op|
        op.responses = Open::Api::OperationItem::Responses{
          "200" => Open::Api::Response.new(%summary).tap do |resp|
            resp.content = {
              "application/json" => Open::Api::MediaType.new(schema: %schema),
            }
          end,
          "400"     => Granite::Api.open_api.response_ref("400"),
          "401"     => Granite::Api.open_api.response_ref("401"),
          "403"     => Granite::Api.open_api.response_ref("403"),
          "404"     => Granite::Api.open_api.response_ref("404"),
          "500"     => Granite::Api.open_api.response_ref("500"),
          "default" => Granite::Api.open_api.response_ref("default"),
        }

        unless %params.nil?
          op.parameters.concat %params
        end

        unless %security.nil?
          op.security = %security
        end

        unless %tags.nil?
          op.tags = %tags
        end
      end
    end

    if %op_item.is_a?(Open::Api::OperationItem)
      Granite::Api.open_api.add_path(%open_api_path, Open::Api::Operation.parse({{typ}}), %op_item)
    else
      # Log.error { "Invalid route: " + {{path}} }
    end
  end
end
