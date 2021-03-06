defmodule Upstream.Worker.LargeFile do
  @moduledoc """
  LargeFile Uploader handles all the interaction to upload a large file.
  """
  use Upstream.Worker.Base

  alias Upstream.Uploader.Status
  alias Upstream.B2.LargeFile
  alias Upstream.Worker.Chunk

  # Client API

  def cancel(job_name) do
    GenServer.call(via_tuple(job_name), :cancel)
  end

  # Server Callbacks

  def handle_call(:cancel, _from, state) do
    {:ok, cancelled} = LargeFile.cancel(state.file_id)
    new_state = Map.merge(state, %{current_state: :cancelled})

    {:reply, cancelled, new_state}
  end

  # Upstream.Worker.Base Callbacks

  def task(state) do
    stream =
      Task.Supervisor.async_stream(
        TaskSupervisor,
        chunk_streams(state.job.stream, state.temp_directory),
        &upload_chunk(&1, state.file_id, state.job, state.status),
        max_concurrency: Upstream.concurrency(),
        timeout: 100_000_000
      )

    Stream.run(stream)

    Logger.info("[Upstream] #{Status.uploaded_count(state.status)} part(s) uploaded")
    sha1_array = Status.get_uploaded_sha1(state.status)
    LargeFile.finish(state.file_id, sha1_array)
  end

  ## Private Callbacks

  defp handle_setup(state) do
    {:ok, status} = Status.start_link()

    {:ok, started} = LargeFile.start(state.uid.name, state.job.metadata)

    temp_directory = Path.join(["tmp", started.file_id])
    :ok = File.mkdir_p!(temp_directory)

    Map.merge(state, %{
      file_id: started.file_id,
      temp_directory: temp_directory,
      status: status
    })
  end

  defp handle_stop(state) do
    Status.stop(state.status)
    File.rmdir(state.temp_directory)

    if state.current_state in [:started, :uploading], do: LargeFile.cancel(state.file_id)
  end

  # Private Functions

  defp chunk_streams(stream, temp_directory) do
    stream
    |> Stream.with_index()
    |> Stream.map(fn {chunk, index} ->
      path = Path.join([temp_directory, "#{index}"])
      {Enum.into(chunk, File.stream!(path, [], 2048)), index}
    end)
  end

  defp upload_chunk({chunked_stream, index}, file_id, job, status) do
    content_length =
      if job.threads == index + 1, do: job.last_content_length, else: job.content_length

    chunk_state = %{
      job: %{stream: chunked_stream, content_length: content_length},
      uid: %{index: index, file_id: file_id}
    }

    case Chunk.task(chunk_state) do
      {:ok, part} ->
        Status.add_uploaded({index, part.content_sha1}, status)
        File.rm!(chunked_stream.path)

      {:error, _} ->
        Logger.info("[Upstream] Error #{job.uid.name} chunk: #{index}")
    end
  end
end
