module Granite::Type
  def from_rs(result : DB::ResultSet, t : UUID.class)
    result.read UUID
  end

  def from_rs(result : DB::ResultSet, t : (UUID | Nil).class)
    result.read UUID?
  end
end

class Granite::Base
  macro enum_column(name, _enum, _default)
    column {{name.id}} : {{_enum}} = {{_enum}}::{{_default}},
      converter: Granite::Converters::Enum({{_enum}}, String)
  end

  macro unix_timestamps
    column created_at : Int64
    column modified_at : Int64

    before_save do
      # Log.warn { "SETTING TIMES: #{Time.utc.to_unix}"}
      self.created_at = Time.utc.to_unix if @created_at.nil?
      self.modified_at = Time.utc.to_unix
    end
  end
end
