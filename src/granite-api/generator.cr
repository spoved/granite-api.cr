require "./generator/*"

module Granite::Api
  # Generates CRUD routes for `Granite` models
  macro crud_routes(_model, api_version = 1)
    {% model = _model.resolve.resolve %}

    {% if !(model < Granite::Base) %}
      {% raise "only support sub classes of Granite::Base" %}
    {% end %}

    {% primary_key = model.instance_vars.find { |var| var.annotation(Granite::Column) && var.annotation(Granite::Column)[:primary] } %}
    {% if primary_key.nil? %}
      {% raise "must have primary key" %}
    {% end %}
    {% id_class = primary_key.type.union_types.first %}

    %api_version = "v{{api_version}}"
    %model_name = Granite::Api._api_model_name({{model.id}})
    %path : String =  %model_name
    %open_api = Granite::Api.open_api

    Log.info &.emit "Generating CRUD routes for {{model}}"
    %model_def : Granite::Api::ModelDef({{model.id}}) = Granite::Api::ModelDef({{model.id}}).new(%model_name, %path)

    Granite::Api.register_schema({{model}}, %model_def)
    %resp_list_object_name, %resp_list_object = Granite::Api.create_list_schemas(%model_def.name)
    %open_api.register_schema(%resp_list_object_name, %resp_list_object) unless %open_api.has_schema_ref?(%resp_list_object_name)
    %patch_body_params = %model_def.body_params
    %patch_body_object = Granite::Api.create_patch_body_schemas(%model_def)

    ###### GET List ######

    %get_list_path = "/api/#{%api_version}/#{%path}"
    %open_api.add_path(%get_list_path, Open::Api::Operation::Get,
      item: Granite::Api.create_get_list_op_item(
        model_name: %model_def.name,
        params: Granite::Api.list_req_params + %model_def.coll_filter_params,
        resp_ref: %open_api.schema_ref(%resp_list_object_name)
      )
    )

    Granite::Api.register_route("GET", %get_list_path, {{model.id}})
    get %get_list_path do |env|
      env.response.content_type = "application/json"
      limit, offset = Granite::Api.limit_offset_args(env)
      sort_by, sort_order = Granite::Api.sort_args(env)
      filters = Granite::Api.param_args(env, %model_def.coll_filter_params)

      Log.notice &.emit "get {{model.id}}", filters: filters.to_json, limit: limit,
        offset: offset, sort_by: sort_by, sort_order: sort_order

      query = {{model.id}}.where

      # If sort is not specified, sort by provided column
      %model_def.sort_by.call(sort_by, sort_order, query)

      # If filters are specified, apply them
      %model_def.apply_filters.call(filters, query)

      total = query.size.run
      query.offset(offset) if offset > 0
      query.limit(limit) if limit > 0
      items = query.select
      resp = { limit:  limit, offset: offset, size: items.size, total:  total, items:  items }
      Granite::Api.set_content_length(resp.to_json, env)
    rescue ex
      Log.error(exception: ex) {ex.message}
      Granite::Api.resp_400(env, ex.message)
    end

    ###### GET By Id ######
    %path_id_param = Open::Api::Parameter.new(
      %model_def.primary_key,
      %model_def.primary_key_type,
      location: "path",
      description: "id of record", required: true
    )
    %open_api.add_path("/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}", Open::Api::Operation::Get,
      item: Granite::Api.create_get_op_item(
        model_name: %model_def.name,
        params: [
          %path_id_param
        ],
        resp_ref: %open_api.schema_ref(%model_def.name)
      )
    )

    Granite::Api.register_route("GET", "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}", {{model.id}})
    get "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}" do |env|
      env.response.content_type = "application/json"
      id = env.params.url[%model_def.primary_key]
      Log.notice &.emit "get {{model.id}}", id: id
      item = {{model.id}}.find({{id_class}}.new(id))
      if item.nil?
        Granite::Api.not_found_resp(env, "Record with id: #{id} not found")
      else
        Granite::Api.set_content_length(item.to_json, env)
      end
    rescue ex
      Log.error(exception: ex) {ex.message}
      Granite::Api.resp_400(env, ex.message)
    end

    ###### DELETE By Id ######
    Granite::Api.register_route("DELETE", "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}", {{model.id}})
    %open_api.add_path("/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}", Open::Api::Operation::Delete,
      item: Granite::Api.create_delete_op_item(
        model_name: %model_def.name,
        params: [
          %path_id_param
        ],
      )
    )

    delete "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}" do |env|
      env.response.content_type = "application/json"
      env.response.content_type = "application/json"
      id = env.params.url[%model_def.primary_key]
      Log.notice &.emit "delete {{model.id}}", id: id
      item = {{model.id}}.find({{id_class}}.new(id))
      if item.nil?
        Granite::Api.not_found_resp(env, "Record with id: #{id} not found")
      else
        item.destroy!
        Granite::Api.resp_204(env)
      end
    rescue ex
      Log.error(exception: ex) {ex.message}
      Granite::Api.resp_400(env, ex.message)
    end


    ###### POST/PUT ######
    Granite::Api.register_route("PUT", "/api/#{%api_version}/#{%path}", {{model.id}})
    %open_api.add_path("/api/#{%api_version}/#{%path}", Open::Api::Operation::Put,
      item: Granite::Api.create_put_op_item(
        model_name: %model_def.name,
        model_ref: %open_api.schema_ref(%model_def.name),
        body_schema: Granite::Api.body_schema({{model.id}}),
      )
    )

    put "/api/#{%api_version}/#{%path}" do |env|
      env.response.content_type = "application/json"

      item = {{model}}.new
      values = Granite::Api.param_args(env, %patch_body_params)
      %model_def.patch_item.call(item, values)

      if item.save
        Granite::Api.set_content_length(item.to_json, env)
      else
        Granite::Api.resp_400(env, item.errors)
      end
    rescue ex
      Log.error(exception: ex) {ex.message}
      Granite::Api.resp_400(env, ex.message)
    end

    ###### PATCH ######

    Granite::Api.register_route("PATCH", "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}", {{model.id}})
    %open_api.add_path("/api/#{%api_version}/#{%path}/{#{%model_def.primary_key}}", Open::Api::Operation::Patch,
      item: Granite::Api.create_patch_op_item(
        model_name: %model_def.name,
        params: [
          %path_id_param
        ],
        body_object: %patch_body_object,
        model_ref: %open_api.schema_ref(%model_def.name)
      )
    )

    patch "/api/#{%api_version}/#{%path}/:#{%model_def.primary_key}" do |env|
      env.response.content_type = "application/json"
      id = env.params.url[%model_def.primary_key]
      Log.notice &.emit "patch {{model.id}}", id: id
      item = {{model.id}}.find({{id_class}}.new(id))
      if item.nil?
        Granite::Api.not_found_resp(env, "Record with id: #{id} not found")
      else
        values = Granite::Api.param_args(env, %patch_body_params)
        %model_def.patch_item.call(item, values)
        if item.save
          Granite::Api.set_content_length(item.to_json, env)
        else
          Granite::Api.resp_400(env, item.errors)
        end
      end
    rescue ex
      Log.error(exception: ex) {ex.message}
      Granite::Api.resp_400(env, ex.message)
    end

    Log.info { "Generating relationship routes for {{model.id}}" }
    # Relationships
    {% for meth in model.methods %}
      {% if meth.annotation(Granite::Relationship) %}
        {% anno = meth.annotation(Granite::Relationship) %}
        %target_object_name = Granite::Api._api_model_name({{anno[:target]}})
        Log.debug {"registering relationship: #{%model_def.name} -> #{%target_object_name}, type: {{anno[:type]}}"}
        Granite::Api.define_relationships(
          {{model.id}},
          %model_def,
          {{meth.name}},
          Granite::Api::ModelDef({{anno[:target]}}).new(
            %target_object_name, "#{%path}/{#{%model_def.primary_key}}/#{%target_object_name}"
          ),
          {{anno[:type]}}, {{anno[:target]}}, :{{anno[:foreign_key]}},
          %path_id_param, %api_version, {{id_class}})
      {% end %}
    {% end %}
  end
end
