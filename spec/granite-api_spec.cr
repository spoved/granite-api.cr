require "./spec_helper"

describe Granite::Api do
  it TestModel do
    model_def = Granite::Api::ModelDef(TestModel).new("test_model", "test_model")
    model_def.should be_a Granite::Api::ModelDef(TestModel)
  end
end
