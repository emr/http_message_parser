defmodule HttpMessageParser.StatusCode do
  def valid?(status) do
    "assets/status_codes.txt"
    |> File.read!()
    |> String.split("\n")
    |> Enum.find_value(false, fn x -> x == status end)
  end
end
