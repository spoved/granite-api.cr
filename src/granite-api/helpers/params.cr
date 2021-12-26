module Granite::Api
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
    filters = Array(ParamFilter).new
    filter_params.each do |param|
      val = param_filter(param, env)
      unless val.nil?
        filters << val
      end
    end

    val = env.params.query["filters"]?.nil? ? nil : env.params.query["filters"]
    unless val.nil?
      begin
        Array(NamedTuple(name: String, op: String, value: Bool | Float64 | Int32 | Int64 | String | Array(String)))
          .from_json(val).each do |filter|
          filters << {
            name:  filter[:name],
            op:    string_to_operator(filter[:op]),
            value: filter[:value],
          }
        end
      rescue ex : JSON::ParseException
        raise "invalid filter"
      rescue ex
        Log.error(exception: ex) { ex.message }
        raise ex
      end
    end

    filters
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

  # Create `Open::Api::Parameter` for the provided column type
  def filter_params_for_var(name, type, **args) : Array(Open::Api::Parameter)
    params = [] of Open::Api::Parameter
    params << Open::Api::Parameter.new(name, **args, type: type, description: "return results that match #{name}")
    params
  end
end
