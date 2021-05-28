defmodule SimpleHTTPServer do
  require Logger

  defmodule Request do
    defstruct [:method, :path, :headers, :body]
  end

  def start_link(opts) do
    {:ok, spawn_link(__MODULE__, :init, [opts])}
  end

  def init(opts) do
    port = Keyword.get(opts, :port, 4000)
    {:ok, sock} = :gen_tcp.listen(port, [:binary, {:active, false}, {:reuseaddr, true}])

    accept_loop(sock)
  end

  defp accept_loop(sock) do
    {:ok, conn} = :gen_tcp.accept(sock)

    # POST /foo-bar HTTP/1.1\r\nHost: localhost:4000\r\nUser-Agent: curl/7.68.0\r\nAccept: */*\r\nContent-Length: 8\r\nContent-Type: application/x-www-form-urlencoded\r\n\r\nfoo=dang
    # parse the request
    :ok = :inet.setopts(conn, packet: :line)

    read_conn = fn length -> :gen_tcp.recv(conn, length, 1000) end

    [method_line | header_lines] =
      Stream.cycle([0])
      |> Stream.map(fn _ ->
        {:ok, line} = read_conn.(0)
        line
      end)
      |> Enum.take_while(&(&1 != "\r\n"))

    {method, path} = parse_method_line(method_line)

    headers =
      header_lines
      |> Enum.map(fn h ->
        [k, v] = h |> String.split(":", parts: 2)
        {String.downcase(k), String.trim(v)}
      end)

    {_, content_length} = List.keyfind(headers, "content-length", 0, {"content-length", "0"})
    content_length = String.to_integer(content_length)

    :ok = :inet.setopts(conn, packet: :raw)

    {:ok, body} =
      if content_length == 0 do
        {:ok, nil}
      else
        read_conn.(content_length)
      end

    request = %Request{
      method: method,
      path: path,
      headers: headers,
      body: body
    }

    Logger.debug(msg: "RECEIVED REQUEST", request: request)

    :ok =
      :gen_tcp.send(
        conn,
        "HTTP/1.1 200 OK\r\ncontent-type: text/plain\r\ncontent-length: 2\r\n\r\nOK"
      )

    accept_loop(sock)
  end

  defp parse_method_line(method_line) do
    [method, path_and_http_version] = String.split(method_line, " ", parts: 2)

    {
      parse_method(String.downcase(method)),
      path_and_http_version
      |> String.replace("HTTP/1.1", "")
      |> String.replace("HTTP/1.0", "")
      |> String.trim()
    }
  end

  defp parse_method("get"), do: :get
  defp parse_method("post"), do: :post
end
