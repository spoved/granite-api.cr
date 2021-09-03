module Granite::Api
  def list_req_params
    [
      OPEN_API.parameter_ref("resp_limit"),
      OPEN_API.parameter_ref("resp_offset"),
      OPEN_API.parameter_ref("resp_sort_by"),
      OPEN_API.parameter_ref("resp_sort_order"),
    ]
  end

  def limit_offset_args(env)
    limit = env.params.query["limit"]?.nil? ? DEFAULT_LIMIT : env.params.query["limit"].to_i
    offset = env.params.query["offset"]?.nil? ? 0 : env.params.query["offset"].to_i

    {limit, offset}
  end

  def sort_args(env)
    sort_by = env.params.query["sort_by"]?.nil? ? Array(String).new : env.params.query["sort_by"].split(",")
    sort_order = env.params.query["sort_order"]?.nil? ? "asc" : env.params.query["sort_order"]
    {sort_by, sort_order}
  end

  def order_by_args(env)
    order_by = env.params.query["order_by"]?.nil? ? nil : env.params.query["order_by"]
    if order_by.nil?
      Array(String).new
    else
      order_by.split(',')
    end
  end
end
