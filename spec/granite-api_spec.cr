require "./spec_helper"

describe Granite::Api do
  it "renders /" do
    get "/"
    response.body.should eq "Hello World!"
  end
end
