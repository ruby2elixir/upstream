defmodule Upstream.B2.Account.Authorization do
  @moduledoc """
  Handles Authorization of B2 account.
  """

  defstruct [
    :account_id,
    :authorization_token,
    :api_url,
    :download_url,
    :recommended_part_size,
    :absolute_minimum_part_size
  ]

  @type t :: %__MODULE__{
          account_id: String.t(),
          authorization_token: String.t(),
          api_url: String.t(),
          download_url: String.t(),
          recommended_part_size: integer,
          absolute_minimum_part_size: integer
        }
  @doc """
  Authorize#call function will make a call to the api and authorize based on the
  account_id, and application_key passed in from the config.

  config :upstream, Upstream, 
    account_id: <whatever account_id>,
    application_key: <whatever application_key>
  """
  use Upstream.B2.Base

  def url(_), do: Url.generate(:authorize_account)

  def header do
    encoded =
      "Basic " <>
        Base.encode64(Upstream.config(:account_id) <> ":" <> Upstream.config(:application_key))

    [{"Authorization", encoded}]
  end
end
