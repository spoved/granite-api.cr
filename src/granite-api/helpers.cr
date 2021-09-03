require "./helpers/*"

module Granite::Api
  macro _api_model_name(model)
    {{model.id.stringify.split("::").last.gsub(/:+/, "_").underscore}}
  end
end
