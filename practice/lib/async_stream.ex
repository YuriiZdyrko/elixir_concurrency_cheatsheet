defmodule Practice.AsyncStream do
  @enumerable 1..20
  @supervisor Practice.TaskSupervisor

  # async_stream_nolink:
  # Despite failure of individual Tasks, stream enumeration goes on
  def run_no_link_failure do
    Task.Supervisor.async_stream_nolink(@supervisor, @enumerable, &fun_failure/1)
    # |> Enum.to_list()
    |> Enum.each(fn item ->
      case item do
        {:exit, error} ->
          IO.inspect("error: #{inspect(error)}")

        {:ok, value} ->
          IO.inspect("#{inspect(item)} value: #{inspect(value)}")
      end
    end)
  end

  # async_stream: no errors
  def run do
    Task.Supervisor.async_stream(@supervisor, @enumerable, &fun/1)
    # |> Enum.to_list()
    |> Enum.each(fn item ->
      IO.write("#{inspect(item)}")
    end)
  end

  # async_stream: Task failure brings caller process down
  # iex> self() => #PID<0.279.0>
  # iex> Practice.AsyncStream.run_failure()
  # iex> self() => #PID<0.296.0>
  def run_failure do
    Task.Supervisor.async_stream(@supervisor, @enumerable, &fun_failure/1)
    |> Enum.to_list()
  end

  def run_max_speed do
    Task.Supervisor.async_stream(
      @supervisor,
      @enumerable,
      &fun/1,
      # 4 on each core
      max_concurrency: System.schedulers_online() * 4,
      # results will arrive out of order
      ordered: false,
      # window for a task to complete, default is 5000
      timeout: 500,
      # return {:exit, :timeout] if task exceeds timeout
      on_timeout: :kill_task
    )
  end

  def fun(arg) do
    Process.sleep(:rand.uniform(4000))
    
    # This will not stop enumeration
    if arg in [10, 11, 12] do
      Process.exit(self(), :normal)
    end
    
    # This would stop async_stream enumeration with error
    # Process.exit(self(), :kill)

    # This too
    # throw("Task failed :(")

    IO.inspect("Worker #{inspect(arg)} done")
  end

  def fun_failure(arg) do
    Process.sleep(:rand.uniform(500))

    if arg in [10, 11, 12] do
      throw("Task failed :(")
    end

    IO.inspect("Worker #{inspect(arg)} done")
    arg
  end
end
