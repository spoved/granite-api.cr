module Granite::Api
  def not_found_resp(env, msg)
    env.response.status_code = 404
    env.response.content_type = "application/json"
    env.response.print(set_content_length({code: 404, message: msg}.to_json, env))
    env.response.close
  end

  def resp_204(env)
    env.response.status_code = 204
    env.response.close
  end

  macro resp_400(env, msg)
    {{env}}.response.status_code = 400
    {{env}}.response.content_type = "application/json"
    halt {{env}}, status_code: 400, response: ({code: 400, message: {{msg}}}.to_json)
  end

  def set_content_length(resp, env)
    resp = "{}" if resp.nil?
    env.response.content_length = resp.bytesize
    resp
  end

  def response_data(limit, offset, data, total)
    {
      limit:  limit,
      offset: offset,
      size:   data.size,
      total:  total,
      data:   data,
    }
  end
end
