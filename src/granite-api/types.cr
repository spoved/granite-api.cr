module Granite::Api
  # :nodoc:
  alias PropertyTypes = Int32.class | Int64.class | Nil.class | UUID.class | Bool.class | String.class |
                        (Int32 | Nil).class | (Int64 | Nil).class | (UUID | Nil).class | (Bool | Nil).class | (String | Nil).class

  # :nodoc:
  record CollParamDef, name : String, primary : Bool, coll_param : Open::Api::Parameter, filter_params : Array(Open::Api::Parameter),
    type : PropertyTypes,
    default_value : Int32 | Int64 | Nil | UUID | Bool | String do
  end

  alias ParamFilter = NamedTuple(name: String, op: Symbol, value: Bool | Float64 | Int64 | String | Array(String))
end
