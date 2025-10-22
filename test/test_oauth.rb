require_relative "test_helper"
require "webrick"

class TestOauthHelpers < Minitest::Test
  include TestHelper

  def test_oauth_request_handler_extracts_code
    code_container = { code: nil }
    # Create a fake server object with shutdown method
    server = Object.new
    def server.shutdown; end

    handler = Syodosima.oauth_request_handler(code_container, server)

    # Build a fake WEBrick request/response
    req = OpenStruct.new(query_string: "code=abc123", query: {})
    res = OpenStruct.new
    res.body = nil
    res.content_type = nil

    # Call the proc
    handler.call(req, res)

    assert_equal "abc123", code_container[:code]
    assert_match(/認証成功/, res.body)
    assert_match(%r{text/html}, res.content_type)
  end

  def test_create_webrick_server_returns_server
    # call with a free port; ensure it responds with a WEBrick::HTTPServer-like object
    srv = Syodosima.create_webrick_server(0)
    assert srv.is_a?(WEBrick::HTTPServer)
    srv.shutdown
  end
end
