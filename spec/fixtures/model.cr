require "granite/adapter/sqlite"
require "granite/adapter/mysql"

class TestModel < Granite::Base
  enum Status
    None
    Pending
    Done
  end

  connection sqlite
  table test_model
  column id : Int64, primary: true
  column name : String
  column count : Int32 = 0
  enum_column :status, TestModel::Status, None
  unix_timestamps
end

class DeckCard < Granite::Base
  connection sqlite
  table deck_card
  column uuid : UUID, primary: true
  column name : String
  column count : Int32 = 0
  unix_timestamps
end
