module Granite::Transactions
  module ClassMethods
    # PR: https://github.com/amberframework/granite/pull/454
    def set_timestamps(*, to time = Time.local(Granite.settings.default_timezone), mode = :create)
      {% if @type.instance_vars.select { |ivar| ivar.annotation(Granite::Column) && ivar.type == Time? }.map(&.name.stringify).includes? "created_at" %}
        if mode == :create
          @created_at = time.at_beginning_of_second
        end
      {% end %}

      {% if @type.instance_vars.select { |ivar| ivar.annotation(Granite::Column) && ivar.type == Time? }.map(&.name.stringify).includes? "updated_at" %}
        @updated_at = time.at_beginning_of_second
      {% end %}
    end
  end
end

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

    before_save :pre_commit

    def pre_commit
      self.created_at = Time.utc.to_unix if @created_at.nil?
      self.modified_at = Time.utc.to_unix
    end
  end
end
