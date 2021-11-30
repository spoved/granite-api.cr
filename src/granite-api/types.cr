module Granite::Api
  # :nodoc:
  alias PropertyTypes = Int32.class | Int64.class | Float32.class | Float64.class | Nil.class | UUID.class | Bool.class | String.class | Time.class |
                        (Int32 | Nil).class | (Int64 | Nil).class | (Float32 | Nil).class | (Float64 | Nil).class | (UUID | Nil).class |
                        (Bool | Nil).class | (String | Nil).class | (JSON::Any | Nil).class | (Time | Nil).class

  # :nodoc:
  record CollParamDef,
    name : String,
    primary : Bool,
    coll_param : Open::Api::Parameter,
    filter_params : Array(Open::Api::Parameter),
    type : PropertyTypes,
    default_value : Int32 | Int64 | Float32 | Float64 | Nil | UUID | Bool | String

  alias ParamFilter = NamedTuple(name: String, op: Symbol, value: Bool | Float64 | Int32 | Int64 | String | Array(String))

  struct ListResp(T)
    include JSON::Serializable

    property limit : Int32
    property offset : Int32
    property size : Int32
    property total : Int32
    property items : Array(T)
  end
end
