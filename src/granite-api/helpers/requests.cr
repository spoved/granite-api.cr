module Granite::Api
  def list_req_params
    [
      OPEN_API.parameter_ref("resp_limit"),
      OPEN_API.parameter_ref("resp_offset"),
      OPEN_API.parameter_ref("resp_order_by"),
    ]
  end

  def limit_offset_args(env)
    limit = env.params.query["limit"]?.nil? ? DEFAULT_LIMIT : env.params.query["limit"].to_i
    offset = env.params.query["offset"]?.nil? ? 0 : env.params.query["offset"].to_i

    {limit, offset}
  end

  def order_by_args(env) : Hash(String, Symbol)
    order_by = env.params.query["order_by"]?.nil? ? Array(String).new : env.params.query["order_by"].split(",")
    order_by.to_h do |item|
      parts = item.split(":")
      {parts.first, parts.last == "desc" ? :desc : :asc}
    end
  end
end
