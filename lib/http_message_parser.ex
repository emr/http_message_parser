defmodule HttpMessageParser.Request do
  @moduledoc """
  `Request` properties:
    * `:method` - HTTP method as an atom (`:get`, `:head`, `:post`, `:put`, `:delete`, etc.)
    * `:path` - target path as a binary string or char list
    * `:http_version` - HTTP version specified by the request
    * `:body` - request body
    * `:headers` - HTTP headers as an orddict (e.g., `[{"Accept", "application/json"}]`)
    * `:params` - Query parameters as a map
  """
  @enforce_keys [:method, :path]
  defstruct method: nil, path: nil, http_version: nil, headers: [], body: "", params: %{}

  @type method :: :get | :post | :put | :patch | :delete | :options | :head
  @type headers :: [{atom, binary}] | [{binary, binary}] | %{binary => binary} | any
  @type path :: binary | any
  @type http_version :: binary
  @type body :: binary | charlist | iodata | {:form, [{atom, any}]} | {:file, binary} | any
  @type params :: map

  @type t :: %__MODULE__{
          method: method,
          path: binary,
          http_version: binary | nil,
          headers: headers,
          body: body,
          params: params
        }
end

defmodule HttpMessageParser.Response do
  @moduledoc """
  `Response` properties:
    * `:status_code` - fully qualified status code
    * `:http_version` - HTTP version specified by the response
    * `:body` - response body
    * `:headers` - HTTP headers as an orddict (e.g., `[{"Accept", "application/json"}]`)
  """
  @enforce_keys [:status_code, :http_version]
  defstruct status_code: nil, http_version: nil, body: "", headers: %{}

  @type t :: %__MODULE__{
          status_code: binary,
          http_version: binary,
          body: term,
          headers: list
        }
end

defmodule HttpMessageParser do
  defdelegate parse_request(message), to: HttpMessageParser.Parser
  defdelegate parse_response(message), to: HttpMessageParser.Parser
end
