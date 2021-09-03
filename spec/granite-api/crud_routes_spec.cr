require "../spec_helper"

describe Granite::Api do
  it "GET /api/v1/test_model" do
    get "/api/v1/test_model"
    expected = %<{"limit":100,"offset":0,"size":1,"total":1,"items":[{"id":1,"name":"first_record","count":101,"status":"done","created_at":1630692214,"modified_at":1630692214}]}>
    response.body.should eq expected
  end
  it "GET /api/v1/test_model/:id" do
    get "/api/v1/test_model/1"
    expected = %<{"id":1,"name":"first_record","count":101,"status":"done","created_at":1630692214,"modified_at":1630692214}>
    response.body.should eq expected
    response.content_type.should eq "application/json"
  end

  it "DELETE /api/v1/test_model/:id" do
    model = TestModel.new(name: "delete_me", count: 5)
    model.valid?.should be_true
    model.errors.should be_empty
    model.save.should be_true
    model.errors.should be_empty

    delete "/api/v1/test_model/#{model.id}"
    response.body.should be_empty
    response.status_code.should eq 204
  end

  it "PUT /api/v1/test_model" do
    count = Random.rand(1000)
    body = %<{"name":"put_test","count":#{count},"status":"pending"}>
    put "/api/v1/test_model", HTTP::Headers{"Content-Type" => "application/json"}, body

    response.status_code.should eq 200
    response.content_type.should eq "application/json"
    response.body.should_not be_empty
    resp_body = JSON.parse(response.body)

    resp_body["count"].as_i.should eq count

    model = TestModel.find(resp_body["id"].as_i64)
    model.destroy if model
    model.not_nil!.destroyed?.should eq true
  end

  it "PATCH /api/v1/test_model/:id" do
    count = Random.rand(1000)
    model = TestModel.new(name: "patch_me", count: count)
    model.save.should be_true

    new_count = Random.rand(1000)
    body = %<{"count":#{new_count}}>
    patch "/api/v1/test_model/#{model.id}", HTTP::Headers{"Content-Type" => "application/json"}, body
    response.status_code.should eq 200
    response.content_type.should eq "application/json"
    response.body.should_not be_empty
    resp_body = JSON.parse(response.body)
    resp_body["count"].as_i.should eq new_count

    model.destroy
    model.destroyed?.should eq true
  end
end
