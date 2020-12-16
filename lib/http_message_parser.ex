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
  defstruct method: nil, path: nil, http_version: nil, headers: [], body: nil, params: %{}

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
  defstruct status_code: nil, http_version: nil, body: nil, headers: %{}

  @type t :: %__MODULE__{
          status_code: binary,
          http_version: binary,
          body: term,
          headers: list
        }
end

defmodule HttpMessageParser do
  @moduledoc ~S"""
  Parses the given `message` in HTTP message format.

  ## Parsing Messages

  Use `HttpMessageParser.parse_request` for parsing request messages.

  Use `HttpMessageParser.parse_response` for parsing response messages.

  When just a valid request line is passed, returns a request struct with empty body and headers.
  ```
  iex> HttpMessageParser.parse_request "GET /users/1 HTTP/1.1"
  {:ok, %HttpMessageParser.Request{
    method: :get,
    path: "/users/1",
    http_version: "HTTP/1.1",
    body: nil,
    headers: [],
    params: %{}
  }}
  ```

  The same goes for status line of response messages:
  ```
  iex> HttpMessageParser.parse_response "HTTP/0.9 200 OK"
  {:ok, %HttpMessageParser.Response{
    status_code: 200,
    http_version: "HTTP/0.9",
    body: nil,
    headers: []
  }}
  iex> HttpMessageParser.parse_response "HTTP/2 200"
  {:ok, %HttpMessageParser.Response{
    status_code: 200,
    http_version: "HTTP/2",
    body: nil,
    headers: []
  }}
  ```

  Headers are separated by lines, and each line is separated by colons.
  Spaces on the key side are preserved. However, spaces on the value side are removed.
  When duplicate keys are provided, both are added to the list.
  Here is a full example that covers all these cases:
  ```
  iex> HttpMessageParser.parse_request "POST /users/3 HTTP/1.1
  ...>Connection: keep-alive
  ...>Accept: text/*
  ...>Host:   github.com
  ...> Spaced Header  Example  :   example value
  ...>Duplicate Header: value 1
  ...>Duplicate Header: value 2
  ...>
  ...>first_name=john&last_name=doe"
  {:ok, %HttpMessageParser.Request{
    method: :post,
    path: "/users/3",
    http_version: "HTTP/1.1",
    body: "first_name=john&last_name=doe",
    headers: [
      {"Connection", "keep-alive"},
      {"Accept", "text/*"},
      {"Host", "github.com"},
      {" Spaced Header  Example  ", "example value"},
      {"Duplicate Header", "value 1"},
      {"Duplicate Header", "value 2"}
    ],
    params: %{}
  }}
  ```

  Here is a full example for a response message:
  ```
  iex> HttpMessageParser.parse_response "HTTP/0.9 200 OK
  ...>Server: nginx/1.14.0 (Ubuntu)
  ...>Date: Mon, 14 Dec 2020 12:40:51 GMT
  ...>Content-type: text/html; charset=UTF-8
  ...>Connection: close
  ...> Spaced Header  Example  :   example value
  ...>
  ...>{\"ok\": true}"
  {:ok, %HttpMessageParser.Response{
    status_code: 200,
    http_version: "HTTP/0.9",
    body: "{\"ok\": true}",
    headers: [
      {"Server", "nginx/1.14.0 (Ubuntu)"},
      {"Date", "Mon, 14 Dec 2020 12:40:51 GMT"},
      {"Content-type", "text/html; charset=UTF-8"},
      {"Connection", "close"},
      {" Spaced Header  Example  ", "example value"}
    ]
  }}
  ```

  Http version can be empty:
  ```
  iex> HttpMessageParser.parse_request "POST /users/5"
  {:ok, %HttpMessageParser.Request{
    method: :post,
    path: "/users/5",
    http_version: nil,
    body: nil,
    headers: [],
    params: %{}
  }}
  ```

  Query parameters in request messages can be captured with `:params` property:
  ```
  iex> HttpMessageParser.parse_request "GET /users/6?format=json"
  {:ok, %HttpMessageParser.Request{
    method: :get,
    path: "/users/6",
    http_version: nil,
    body: nil,
    headers: [],
    params: %{"format" => "json"}
  }}
  ```

  ## Errors

  When something invalid or unexpected is encountered, errors are returned with the following shape:
  ```
  reason :: atom
  info :: binary
  error :: {:error, reason | {reason, info}}
  ```
  Detailed errors are returned with a tuple that contains another tuple as well as `:error`.
  Other errors are returned with a tuple that contains an atom which is the error reason.

  #### `:invalid_request_method`
  When an invalid request method is passed, returns error with reason `:invalid_request_method`.
  ```
  iex> HttpMessageParser.parse_request "FETCH /users/6 HTTP/1.1"
  {:error, {:invalid_request_method, "FETCH"}}
  ```

  When a completely invalid message is passed, returns error with reason `:invalid_request_method`.
  Because the first line must be a valid request line so it must start with a valid method verb.
  ```
  iex> HttpMessageParser.parse_request "this is an invalid message"
  {:error, {:invalid_request_method, "this"}}
  ```

  #### `:invalid_http_version`
  When an invalid http version is passed, returns error with reason `:invalid_http_version`.
  ```
  iex> HttpMessageParser.parse_request "GET /users/8 HTTP/3.9"
  {:error, {:invalid_http_version, "HTTP/3.9"}}
  ```

  #### `:invalid_header`
  When an invalid header is passed, returns error with reason `:invalid_header`
  and adds the invalid value as the third element to the tupple.
  ```
  iex> HttpMessageParser.parse_request "GET /user/9 HTTP/1.1\nan-invalid-header"
  {:error, {:invalid_header, "an-invalid-header"}}
  ```

  When an empty string is passed, returns error with reason `:empty_message`.
  ```
  iex> HttpMessageParser.parse_request ""
  {:error, :empty_message}
  ```
  """
  @spec parse_request(binary) :: {:ok, HttpMessageParser.Request.t} | {:error, atom | {atom, binary}}
  defdelegate parse_request(message), to: HttpMessageParser.Parser
  @spec parse_response(binary) :: {:ok, HttpMessageParser.Response.t} | {:error, atom | {atom, binary}}
  defdelegate parse_response(message), to: HttpMessageParser.Parser
end
