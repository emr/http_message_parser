defmodule HttpMessageParser.Parser do
  @doc ~S"""
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
    body: "",
    headers: %{},
    params: %{}
  }}
  ```

  The same goes for status line of response messages:
  ```
  iex> HttpMessageParser.parse_response "HTTP/0.9 200 OK"
  {:ok, %HttpMessageParser.Response{
    status_code: 200,
    http_version: "HTTP/0.9",
    body: "",
    headers: %{}
  }}

  Headers are separated by lines, and each line is separated by colons.
  Spaces on the key side are preserved. However, spaces on the value side are removed.
  When duplicated keys are provided, only the last one is preserved.
  Here is a full example that covers all these cases:
  ```
  iex> HttpMessageParser.parse_request "POST /users/3 HTTP/1.1
  ...>Connection: keep-alive
  ...>Accept: text/*
  ...>Host:   github.com
  ...> Spaced Header  Example  : example value
  ...>Duplicate Header: value 1
  ...>Duplicate Header: value 2
  ...>
  ...>first_name=john&last_name=doe"
  {:ok, %HttpMessageParser.Request{
    method: :post,
    path: "/users/3",
    http_version: "HTTP/1.1",
    body: "first_name=john&last_name=doe",
    headers: %{
      "Connection" => "keep-alive",
      "Accept" => "text/*",
      "Host" => "github.com",
      " Spaced Header  Example  " => "example value",
      "Duplicate Header" => "value 1, value 2"
    },
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
  ...> Spaced Header  Example  : example value
  ...>
  ...>{\"ok\": true}"
  {:ok, %HttpMessageParser.Response{
    status_code: 200,
    http_version: "HTTP/0.9",
    body: "{\"ok\": true}",
    headers: %{
      "Server" => "nginx/1.14.0 (Ubuntu)",
      "Date" => "Mon, 14 Dec 2020 12:40:51 GMT",
      "Content-type" => "text/html; charset=UTF-8",
      "Connection" => "close",
      " Spaced Header  Example  " => "example value"
    }
  }}
  ```

  Http version can be empty:
  ```
  iex> HttpMessageParser.parse_request "POST /users/5"
  {:ok, %HttpMessageParser.Request{
    method: :post,
    path: "/users/5",
    http_version: nil,
    body: "",
    headers: %{},
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
    body: "",
    headers: %{},
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

  alias HttpMessageParser.Request
  alias HttpMessageParser.Response

  @http_verbs [
    get: "GET",
    post: "POST",
    put: "PUT",
    patch: "PATCH",
    delete: "DELETE",
    options: "OPTIONS",
    head: "HEAD"
  ]
  @http_versions ["HTTP/0.9", "HTTP/1.0", "HTTP/1.1", "HTTP/2.0"]

  @spec parse_request(binary) :: {:error, atom | {atom, binary}} | {:ok, Request}
  def parse_request(message) do
    with {:ok, %{header: header, body: body}} <- parse_message(message),
         {:ok, %{title: request_line, headers: headers}} <- parse_header(header),
         {:ok, request_line} <- parse_request_line(request_line),
         {:ok, headers} <- parse_headers(headers),
         do:
           {:ok,
            %Request{
              method: request_line.method,
              path: request_line.path,
              http_version: request_line.version,
              body: body,
              headers: headers,
              params: request_line.params
            }}
  end

  @spec parse_response(binary) :: {:error, atom | {atom, any}} | {:ok, Response}
  def parse_response(message) do
    with {:ok, %{header: header, body: body}} <- parse_message(message),
         {:ok, %{title: status_line, headers: headers}} <- parse_header(header),
         {:ok, status_line} <- parse_status_line(status_line),
         {:ok, headers} <- parse_headers(headers),
         do:
           {:ok,
            %Response{
              status_code: status_line.status,
              http_version: status_line.version,
              headers: headers,
              body: body
            }}
  end

  defp parse_message(""), do: {:error, :empty_message}

  defp parse_message(message) do
    [header, body] = split_parts(message, "\n\n", 2)
    {:ok, %{header: header, body: body}}
  end

  defp parse_header(token) do
    [title | [headers]] = split_parts(token, "\n", 2)
    {:ok, %{title: title, headers: headers}}
  end

  defp parse_request_line(line) do
    with [token_1, token_2, token_3] <- split_parts(line, " ", 3),
         {:ok, method} <- parse_request_method(token_1),
         %URI{path: path, query: query_string} <- URI.parse(token_2),
         params <- URI.decode_query(to_string(query_string)),
         {:ok, version} <- parse_http_version(token_3, true),
         do: {:ok, %{method: method, path: path, params: params, version: version}}
  end

  defp parse_request_method(token) do
    case List.keyfind(@http_verbs, token, 1) do
      {method, _} -> {:ok, method}
      _ -> {:error, {:invalid_request_method, token}}
    end
  end

  defp parse_http_version("", _optional = true), do: {:ok, nil}

  defp parse_http_version(token, _) when token in @http_versions do
    {:ok, token}
  end

  defp parse_http_version(token, _) do
    {:error, {:invalid_http_version, token}}
  end

  defp parse_status_line(""), do: {:error, :empty_status_line}

  defp parse_status_line(line) do
    with [token_1, token_2] <- split_parts(line, " ", 2),
         {:ok, version} <- parse_http_version(token_1, false),
         {:ok, status} <- parse_status_code(token_2),
         do: {:ok, %{version: version, status: status}}
  end

  defp parse_status_code(token) do
    with true <- HttpMessageParser.StatusCode.valid?(token),
         [code | _] <- String.split(token, " ", parts: 2) do
      {:ok, String.to_integer(code)}
    else
      _ -> {:error, {:invalid_status_code, token}}
    end
  end

  defp parse_headers(""), do: {:ok, %{}}

  defp parse_headers(header) do
    header
    |> String.split("\n")
    |> parse_headers(%{})
  end

  defp parse_headers([], parsed), do: {:ok, parsed}

  defp parse_headers([token | tokens], parsed) do
    case String.split(token, ~r/\:\ {0,}/, parts: 2) do
      [key, value] ->
        parsed = Map.update(parsed, key, value, fn curr -> curr <> ", " <> value end)
        parse_headers(tokens, parsed)

      _ ->
        {:error, {:invalid_header, token}}
    end
  end

  def split_parts(string, by, length) do
    case String.split(string, by, parts: length) do
      parts when length(parts) == length -> parts
      parts -> parts ++ Enum.map(length(parts)..(length - 1), fn _ -> "" end)
    end
  end
end
