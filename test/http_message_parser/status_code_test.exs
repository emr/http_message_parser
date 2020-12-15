defmodule HttpMessageParser.StatusCodeTest do
  use ExUnit.Case, async: true

  test "valid codes" do
    assert true == HttpMessageParser.StatusCode.valid?("200 OK")
    assert true == HttpMessageParser.StatusCode.valid?("404 NOT FOUND")
  end

  test "invalid codes" do
    assert false == HttpMessageParser.StatusCode.valid?("200")
    assert false == HttpMessageParser.StatusCode.valid?("an invalid status")
  end
end
