module Granite::Api
  # Define relationship routes for provided model
  macro define_relationships(_model, model_def, meth_name, target_model_def, rel_type, rel_target, foreign_key,
                             path_id_param, api_version = "v1", id_class = UUID, security = nil)
    {% model = _model.resolve %}
    %model_def = {{model_def}}
    %target_model_def = {{target_model_def}}
    %api_version = {{api_version}}
    %path = %model_def.path
    %open_api = %model_def.open_api
    %path_id_param = {{path_id_param}}
    %security = {{security}}

    Granite::Api.register_schema({{rel_target}}, %target_model_def)

    {% if rel_type == :has_one || rel_type == :belongs_to %}
      %_path_ = "/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}/#{%target_model_def.name}"
      %open_api.add_path(%_path_, Open::Api::Operation::Get,
        item: Granite::Api.create_get_op_item(
          operation_id: "get_#{%model_def.name}_#{%target_model_def.name}",
          model_name: %model_def.name,
          params: [
            %path_id_param
          ],
          resp_ref: %open_api.schema_ref(%target_model_def.name),
          security: %security,
        )
      )
      %_kemal_path = "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}/#{%target_model_def.name}"
      Granite::Api.register_route("GET", %_kemal_path, {{model.id}})
      get %_kemal_path do |env|
        {% if security %}Granite::Api::Auth.authorized?(env, %security){% end %}
        env.response.content_type = "application/json"
        id = env.params.url[%model_def.primary_key]
        item = {{model.id}}.find({{id_class}}.new(id))
        if item.nil?
          Granite::Api.not_found_resp(env, "Record with id: #{id} not found")
        else
          Granite::Api.set_content_length(item.{{meth_name}}.to_json, env)
        end
      rescue ex : Granite::Api::Auth::Unauthorized
        Granite::Api::Auth.unauthorized_resp(env, ex.message)
      rescue ex : Granite::Api::Auth::Unauthenticated
        Granite::Api::Auth.unauthenticated_resp(env)
      rescue ex
        Log.error(exception: ex) {ex.message}
        Granite::Api.resp_400(env, ex.message)
      end

    {% elsif rel_type == :has_many %}
      %resp_list_object_name, %resp_list_object = Granite::Api.create_list_schemas(%target_model_def.name)
      if !%open_api.has_schema_ref?(%resp_list_object_name)
        %open_api.register_schema(%resp_list_object_name, %resp_list_object)
      end

      %_path_ = "/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}/#{%target_model_def.name.pluralize}"
      %open_api.add_path(%_path_, Open::Api::Operation::Get,
        item: Granite::Api.create_get_list_op_item(
          operation_id: "get_#{%model_def.name}_#{%target_model_def.name}_list",
          model_name: %model_def.name,
          params: [
            Granite::Api.list_req_params,
            %target_model_def.coll_filter_params,
            %path_id_param,
          ].flatten,
          resp_ref: %open_api.schema_ref(%resp_list_object_name),
          security: %security,
        )
      )

      %_kemal_path = "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}/#{%target_model_def.name.pluralize}"
      Granite::Api.register_route("GET", %_kemal_path, {{model.id}})
      get %_kemal_path do |env|
        {% if security %}Granite::Api::Auth.authorized?(env, %security){% end %}
        env.response.content_type = "application/json"
        limit, offset = Granite::Api.limit_offset_args(env)
        order_by = Granite::Api.order_by_args(env)
        id = env.params.url[%model_def.primary_key]
        filters = Granite::Api.param_args(env, %target_model_def.coll_filter_params)
        query = {{rel_target}}.where({{foreign_key.id}}: {{id_class}}.new(id))

        # If sort is not specified, sort by provided column
        %target_model_def.order_by.call(order_by, query)

        # If filters are specified, apply them
        %target_model_def.apply_filters.call(filters, query)

        total = query.size.run
        query.offset(offset) if offset > 0
        query.limit(limit) if limit > 0
        items = query.select
        resp = { limit:  limit, offset: offset, size:   items.size, total:  total, items:  items }
        Granite::Api.set_content_length(resp.to_json, env)
      rescue ex : Granite::Api::Auth::Unauthorized
        Granite::Api::Auth.unauthorized_resp(env, ex.message)
      rescue ex : Granite::Api::Auth::Unauthenticated
        Granite::Api::Auth.unauthenticated_resp(env)
      rescue ex
        Log.error(exception: ex) {ex.message}
        Granite::Api.resp_400(env, ex.message)
      end
    {% end %}

  end
end
