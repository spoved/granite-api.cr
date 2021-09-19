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
    result = Array(ParamFilter).new

    filter_params.each do |param|
      val = param_filter(param, env)
      unless val.nil?
        result << val
      end
    end
    result
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
end
