require "./helpers"

module Granite::Api
  # :nodoc:
  class ModelDef(T)
    getter name : String
    getter path : String
    getter properties : Hash(String, Open::Api::SchemaRef) = Hash(String, Open::Api::SchemaRef).new
    getter collumn_params : Array(Granite::Api::CollParamDef) = [] of Granite::Api::CollParamDef
    getter body_params : Array(Open::Api::Parameter) = Array(Open::Api::Parameter).new
    getter resp_list_object_name : String
    getter resp_list_object : Open::Api::SchemaRef
    property apply_filters : Proc(Array(Granite::Api::ParamFilter), Granite::Query::Builder(T), Nil) = ->(filters : Array(Granite::Api::ParamFilter), query : Granite::Query::Builder(T)) {}
    property patch_item : Proc(T, Array(ParamValues), Nil) = ->(item : T, filters : Array(ParamValues)) {}

    def self.new
      {% begin %}
        {% model = @type.type_vars.first %}
        {% anno = model.annotation(Granite::Api::Options) %}
        {% if anno && anno[:model_name] %}
        name = {{ anno[:model_name] }}
        {% else %}
        name = Granite::Api._api_model_name({{model.id}})
        {% end %}
        {% if anno && anno[:path] %}
        path = {{ anno[:path] }}
        {% else %}
        path = Granite::Api._api_model_name({{model.id}})
        {% end %}
        self.new(name, path)
      {% end %}
    end

    def initialize(@name, @path)
      {% begin %}
      {% model = @type.type_vars.first %}
      @resp_list_object_name, @resp_list_object = Granite::Api.create_list_schemas(@name)
      populate_model_def({{model.id}}, self)

      @collumn_params.select { |c| c.name != "created_at" && c.name != "created_at" }.map(&.coll_param).each do |param|
        @body_params << Open::Api::Parameter.new(
          name: param.name,
          parameter_in: "body",
          required: param.required,
          schema: param.schema
        )
      end
      {% end %}
    end

    def coll_names : Array(String)
      self.collumn_params.map(&.name)
    end

    def coll_filter_params : Array(Open::Api::Parameter)
      self.collumn_params.reject(&.primary).flat_map(&.filter_params)
    end

    def coll_params : Array(Open::Api::Parameter)
      self.collumn_params.reject(&.primary).map(&.coll_param)
    end

    def primary_key : String
      self.collumn_params.find(&.primary).not_nil!.name
    end

    def primary_key_type : PropertyTypes
      self.collumn_params.find(&.primary).not_nil!.type
    end

    def open_api
      Granite::Api.open_api
    end

    private macro populate_model_def(_model, model_def)

      {% model = _model.resolve %}
      %model_def = {{model_def}}

      {% primary_key = model.instance_vars.find { |var| var.annotation(Granite::Column) && var.annotation(Granite::Column)[:primary] } %}
      {% id_class = primary_key.type.union_types.first %}
      {% columns = [] of MetaVar %}
      {% enum_check = {} of StringLiteral => BoolLiteral %}
      {% json_check = {} of StringLiteral => BoolLiteral %}

      {% for var in model.instance_vars %}
        {% if var.annotation(Granite::Column) %}
          {% var_type = var.type.union_types.reject(&.==(Nil)).first %}
          {% is_enum = var_type < Enum %}
          {% if is_enum %}{% enum_check[var.id] = is_enum %}{% end %}
          {% is_json = var.annotation(Granite::Api::Formatter) && var.annotation(Granite::Api::Formatter)[:type] == :json %}
          {% if is_json %}{% json_check[var.id] = is_json %}{% end %}

          {% if is_json %}
            %model_def.properties[{{var.id.stringify}}] = Open::Api::Schema.from_type({{var_type.id}})

            # Need to append this to body params
            %model_def.body_params << Open::Api::Parameter.new(
              name: "{{var.id}}",
              parameter_in: "body",
              schema: %model_def.properties[{{var.id.stringify}}],
            )

          {% else %}
            %model_def.collumn_params << Granite::Api::CollParamDef.new(
              name: "{{var.id}}",
              type: {% if enum_check[var.id] %}String{% else %}{{var.type.union_types.first}}{% end %},
              primary: {{var.annotation(Granite::Column)[:primary] ? true : false}},
              default_value: {% if var.has_default_value? %}{{var.default_value}}{% if enum_check[var.id] %}.to_s{% end %}{% else %}nil{% end %},
              filter_params: Granite::Api.filter_params_for_var("{{var.id}}", {% if enum_check[var.id] %}String{% else %}{{var.type}}{% end %}),
              coll_param: Open::Api::Parameter.new(
                "{{var.id}}",
                {% if enum_check[var.id] %}String{% else %}{{var.type}}{% end %},
                description: "return results that match {{var.id}}",
                default_value: {% if var.has_default_value? %}{{var.default_value}}{% if enum_check[var.id] %}.to_s{% end %}{% else %}nil{% end %}
              ),
            )

            %model_def.properties[{{var.id.stringify}}] = Open::Api::Schema.new(
              {% if enum_check[var.id] %}
              schema_type: "string",
              format: "string",
              default: {{var.default_value}}.to_s,
              {% else %}
              schema_type: Open::Api.get_open_api_type({{var.type}}),
              format: Open::Api.get_open_api_format({{var.type}}),
              default: {{var.default_value}}
              {% end %}
            )
          {% end %}

          {% if var.annotation(Granite::Column)[:primary] %}
            # skip the primary key
          {% else %}
            {% columns << var %}
          {% end %}
        {% end %}
      {% end %}

      %model_def.apply_filters = ->(filters : Array(Granite::Api::ParamFilter), query : Granite::Query::Builder({{model.id}})){
        filters.each do |filter|
          Log.debug {"processing filter: #{filter.inspect}"}

          if (filter[:op] == :in || filter[:op] == :nin) && filter[:value].is_a?(Array)
            if filter[:value].as(Array).empty?
              raise "empty value for filter: #{filter}"
              next
            end
          end

          case filter[:name]
          when "{{primary_key.id}}"
            if filter[:value].is_a?(Array(String))
              query.where(filter[:name], filter[:op], filter[:value].as(Array(String)).map {|v| {{id_class}}.new(v.as(String))} )
            else
              query.where(filter[:name], filter[:op], {{id_class}}.new(filter[:value].as(String)))
            end
          {% for column in columns %}
          when "{{column.id}}"
            {% if json_check[column.id] %}
            next
            # Check if the column is an UUID
            {% elsif column.type.union_types.first <= UUID %}
            if filter[:value].is_a?(Array(String))
              query.where(filter[:name], filter[:op], filter[:value].as(Array(String)).map {|v| UUID.new(v.as(String))} )
            else
              query.where(filter[:name], filter[:op], UUID.new(filter[:value].as(String)))
            end
            {% elsif enum_check[column.id] %}
              if filter[:value].is_a?(Array(String))
                query.where(
                  filter[:name],
                  filter[:op],
                  filter[:value].as(Array(String)).map { |v| {{column.type.union_types.first}}.parse(v).to_s }
                )
              else
                query.where(filter[:name], filter[:op], {{column.type.union_types.first}}.parse(filter[:value].as(String)).to_s)
              end
            {% else %}
              query.where(filter[:name], filter[:op], filter[:value])
            {% end %}
          {% end %}
          end
        end
      }

      %model_def.patch_item = ->(item : {{model.id}}, values : Array(ParamValues)){
        values.each do |param|
          case param[:name]
          when "{{primary_key.id}}"
            Log.trace { "patching attr {{primary_key.id}}" }
            item.{{primary_key.id}} = {{id_class}}.new(param[:value].as(String))
          {% for column in columns %}
          when "{{column.id}}"
            Log.trace { "patching attr {{column.id}}" }

            {% if column.annotation(Granite::Api::Formatter) && column.annotation(Granite::Api::Formatter)[:type] == :json %}
              item.{{column.id}} = {{column.type.union_types.find { |t| t != Nil }}}.from_json(param[:value].to_json)
            {% elsif json_check[column.id] %}
            next
            {% elsif enum_check[column.id] %}
            item.{{column.id}} =  {{column.type.union_types.first}}.parse(param[:value].as(String))
            {% elsif column.type.union_types.first <= Time %}
            item.{{column.id}} = Time::Format::ISO_8601_DATE_TIME.parse(param[:value].as(String))
            {% elsif column.type.union_types.first <= UUID %}
            item.{{column.id}} = UUID.new(param[:value].as(String))
            {% elsif column.type.union_types.first <= Int32 %}
            %var = param[:value].as(Float64 | Int32 | Int64 | String)
            item.{{column.id}} = %var.to_i unless %var.nil?
            {% elsif column.type.union_types.first <= Float32 %}
            %var = param[:value].as(Float64 | Int32 | Int64 | String)
            item.{{column.id}} = %var.to_f32 unless %var.nil?
            {% elsif column.type.union_types.first <= Int64 %}
            %var = param[:value].as(Float64 | Int32 | Int64 | String)
            item.{{column.id}} = %var.to_i64 unless %var.nil?
            {% elsif column.type.union_types.first <= Float64 %}
            %var = param[:value].as(Float64 | Int32 | Int64 | String)
            item.{{column.id}} = %var.to_f64 unless %var.nil?
            {% else %}
            %var = param[:value].as({{column.type}})
            item.{{column.id}} = %var unless %var.nil?
            {% end %}
          {% end %}
          else
            raise "unable to patch item attribute: #{param[:name]}"
          end
        end
      }
    end
  end
end
