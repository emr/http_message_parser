defmodule HttpMessageParser.StatusCode do
  @status_codes [
    100..102,
    200..208,
    226,
    300..305,
    307,
    308,
    400..418,
    421..424,
    426,
    428,
    429,
    431,
    444,
    451,
    499,
    500..508,
    510,
    511,
    599
  ]

  def valid?(status) do
    Integer.parse(status)
    |> code_valid?()
  end

  defp code_valid?({code, "" = _string_part_of_status}) do
    @status_codes
    |> Enum.find_value(false, fn
      _.._ = range -> code in range
      curr -> curr == code
    end)
  end

  defp code_valid?(_), do: false
end
