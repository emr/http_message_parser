defmodule HttpMessageParser.StatusCodeTest do
  use ExUnit.Case, async: true

  test "valid codes" do
    assert true == HttpMessageParser.StatusCode.valid?("101")
    assert true == HttpMessageParser.StatusCode.valid?("200")
    assert true == HttpMessageParser.StatusCode.valid?("404")
    assert true == HttpMessageParser.StatusCode.valid?("504")
  end

  test "invalid codes" do
    assert false == HttpMessageParser.StatusCode.valid?("9")
    assert false == HttpMessageParser.StatusCode.valid?("612")
    assert false == HttpMessageParser.StatusCode.valid?("612")
  end
end
