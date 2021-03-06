require "test_helper"
require "shrine/plugins/rack_response"
require "rack/test_app"

describe Shrine::Plugins::RackResponse do
  before do
    @uploader = uploader do
      plugin :rack_response
    end
  end

  it "returns 200 status" do
    uploaded_file = @uploader.upload(fakeio("content"))
    response = uploaded_file.to_rack_response
    assert_equal 200, response[0]
  end

  it "returns Content-Length header with size metadata" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.metadata["size"] = 10
    response = uploaded_file.to_rack_response
    assert_equal "10", response[1]["Content-Length"]
  end

  it "returns Content-Length header with size if metadata is missing" do
    uploaded_file = @uploader.upload(fakeio("content"))
    uploaded_file.metadata.delete("size")
    response = uploaded_file.to_rack_response
    assert_equal "7", response[1]["Content-Length"]
  end

  it "returns Content-Type header with mime_type metadata" do
    uploaded_file = @uploader.upload(fakeio(content_type: "text/plain"))
    response = uploaded_file.to_rack_response
    assert_equal "text/plain", response[1]["Content-Type"]
  end

  it "returns Content-Type header from extension if mime_type metadata is missing" do
    uploaded_file = @uploader.upload(fakeio(content_type: "text/plain"))
    response = uploaded_file.to_rack_response
    assert_equal "text/plain", response[1]["Content-Type"]
  end

  it "returns Content-Type header of application/octet-stream if MIME type is unknown" do
    uploaded_file = @uploader.upload(fakeio(filename: "foo.foo"))
    response = uploaded_file.to_rack_response
    assert_equal "application/octet-stream", response[1]["Content-Type"]
  end

  it "returns Content-Type header of application/octet-stream if MIME type is missing" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    assert_equal "application/octet-stream", response[1]["Content-Type"]
  end

  it "returns Content-Disposition with filename metadata" do
    uploaded_file = @uploader.upload(fakeio(filename: "plain.txt"))
    response = uploaded_file.to_rack_response
    assert_equal "inline; filename=\"plain.txt\"", response[1]["Content-Disposition"]
  end

  it "returns Content-Disposition with id if filename metadata is missing" do
    uploaded_file = @uploader.upload(fakeio, location: "foo/bar/baz")
    response = uploaded_file.to_rack_response
    assert_equal "inline; filename=\"baz\"", response[1]["Content-Disposition"]
  end

  it "returns Content-Disposition with disposition applied" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response(disposition: "attachment")
    assert_equal "attachment; filename=\"#{uploaded_file.id}\"", response[1]["Content-Disposition"]
  end

  it "returns body which yields contents of the file" do
    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    response = uploaded_file.to_rack_response
    yielded_content = []
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal ["a" * 16*1024, "b" * 16*1024, "c" * 4*1024], yielded_content
  end

  it "calls #each_chunk on Down::ChunkedIO when generating body" do
    uploaded_file = @uploader.upload(fakeio("a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024))
    uploaded_file.to_io.instance_eval { def each_chunk; yield read; end }
    response = uploaded_file.to_rack_response
    yielded_content = []
    response[2].each { |chunk| yielded_content << chunk }
    assert_equal ["a" * 16*1024 + "b" * 16*1024 + "c" * 4*1024], yielded_content
  end

  it "closes the file when response is closed" do
    uploaded_file = @uploader.upload(fakeio)
    response = uploaded_file.to_rack_response
    response[2].close
    assert uploaded_file.to_io.closed?
  end
end
