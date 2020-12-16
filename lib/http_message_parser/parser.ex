defmodule HttpMessageParser.Parser do
  @moduledoc """
  Parses the given `message` in HTTP message format.
  Documentation about how to use the library is available at the main module doc.
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
  @http_versions ["HTTP/0.9", "HTTP/1.0", "HTTP/1.1", "HTTP/2.0", "HTTP/2"]

  @spec parse_request(binary) :: {:ok, Request.t} | {:error, atom | {atom, binary}}
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

  @spec parse_response(binary) :: {:ok, Response.t} | {:error, atom | {atom, any}}
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
    with [maybe_code | _] <- String.split(token, " ", parts: 2),
         true <- HttpMessageParser.StatusCode.valid?(maybe_code),
         [code | _] <- String.split(maybe_code, " ", parts: 2) do
      {:ok, String.to_integer(code)}
    else
      _ -> {:error, {:invalid_status_code, token}}
    end
  end

  defp parse_headers(""), do: {:ok, []}

  defp parse_headers(header) do
    header
    |> String.split("\n")
    |> parse_headers([])
  end

  defp parse_headers([], parsed), do: {:ok, parsed}

  defp parse_headers([token | tokens], parsed) do
    case String.split(token, ~r/\:\ {0,}/, parts: 2) do
      [key, value] -> parse_headers(tokens, parsed ++ [{key, value}])
      _ -> {:error, {:invalid_header, token}}
    end
  end

  def split_parts(string, by, length) do
    case String.split(string, by, parts: length) do
      parts when length(parts) == length -> parts
      parts -> parts ++ Enum.map(length(parts)..(length - 1), fn _ -> "" end)
    end
  end
end
