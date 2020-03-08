defmodule Practice.Async do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(nil) do
    # :timer.send_interval(10000, :heartbeat)
    {:ok, %{ref: nil}}
  end

  def start_task do
    GenServer.call(__MODULE__, :start_task)
  end

  # In this case the task is already running, so we just return :ok.
  def handle_call(:start_task, _from, %{ref: ref} = state) when is_reference(ref) do
    {:reply, :ok, state}
  end

  #   This will not terminate Practice.Async process.
  #   Only :DOWN message will be sent, because .async_nolink sets up Process.monitor.
  def handle_call(:start_task, _from, %{ref: nil} = state) do
    task =
      Task.Supervisor.async_nolink(Practice.TaskSupervisor, fn ->
        Process.sleep(2000)
        a = 1
        b = 0
        a / b
      end)

    # We return :ok and the server will continue running
    {:reply, :ok, %{state | ref: task.ref}}
  end

  #  This will terminate Practice.Async process
  def handle_call(:start_task, _from, %{ref: nil} = state) do
    task =
      Task.Supervisor.async(MyApp.TaskSupervisor, fn ->
        Process.sleep(1000)
        throw("Error inside async")
      end)

    # We return :ok and the server will continue running
    {:reply, :ok, %{state | ref: task.ref}}
  end

  # The task completed successfully
  def handle_info({ref, answer}, %{ref: ref} = state) do
    # We don't care about the DOWN message now, so let's demonitor and flush it
    Process.demonitor(ref, [:flush])
    # Do something with the result and then return
    {:noreply, %{state | ref: nil}}
  end

  # The task failed
  def handle_info(msg = {:DOWN, ref, :process, _pid, _reason}, %{ref: ref} = state) do
    # Log and possibly restart the task...
    IO.inspect(":DOWN message: #{inspect(msg)}")
    {:noreply, %{state | ref: nil}}
  end

  def handle_info(:heartbeat, state) do
    IO.puts("i'm alive #{inspect(state)}")
    {:noreply, state}
  end
end
