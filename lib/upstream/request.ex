defmodule Upstream.Request do
  @moduledoc """
  Request module for making and handling network request to b2
  """

  alias Upstream.Error

  @spec post(struct, String.t(), List.t(), Keyword.t()) :: {:ok | :error, %Error{} | struct}
  def post(caller_struct, url, body, headers, options \\ []) do
    default_options = [
      timeout: :infinity,
      recv_timeout: :infinity,
      connect_timeout: :infinity
    ]

    merged_options = Keyword.merge(default_options, options)

    case HTTPoison.post(url, body, headers, merged_options) do
      {:ok, response = %HTTPoison.AsyncResponse{id: _id}} ->
        {:ok, response}

      {:ok, %{status_code: 200, body: body}} ->
        {:ok, struct(caller_struct, process_response(body))}

      {:ok, %{status_code: _, body: body}} ->
        {:error, struct(Error, process_response(body))}

      {:error, %HTTPoison.Error{id: _id, reason: reason}} ->
        {:error, %{error: reason}}
    end
  end

  defp process_response(body) do
    body
    |> Poison.decode!()
    |> Enum.map(fn {k, v} ->
      {String.to_atom(Macro.underscore(k)), v}
    end)
  end
end
