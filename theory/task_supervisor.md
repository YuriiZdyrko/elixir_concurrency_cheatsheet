### Task.Supervisor

Dynamically spawn and supervise tasks.
Started with no children.

[your code] -- calls --> [supervisor] ---- spawns --> [task]

[your code]              [supervisor] <-- ancestor -- [task]
    ^                                                  |
    |--------------------- caller ---------------------|

```elixir
# Short example

{:ok, pid} = Task.Supervisor.start_link()

task =
  Task.Supervisor.async(pid, fn ->
    # Do something
  end)

Task.await(task)
```

```elixir
# As a part of Supervision tree

Supervisor.start_link([
  {Task.Supervisor, name: MyApp.TaskSupervisor}
], strategy: :one_for_one)

# no response:
Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
  # Do something
end)

# await response:
Task.Supervisor.async(MyApp.TaskSupervisor, fn ->
  # Do something
end)
|> Task.await()
```

### Functions
```elixir
options()
    shutdown
        timeout \\ 500
        | :brutal_kill


Task.Supervisor
    
    # The task will be linked also to the caller
    
    async(supervisor(), () -> any(), options()) 
    :: Task.t()

    async(supervisor, module, fun, args, options())
    :: Task.t()

    # The task will not be linked to the caller
    
    async_nolink(supervisor, fun, options())
    :: Task.t()
```

#### More on Task.Supervisor.async
This function spawns a process that is linked to and monitored by the caller process. The linking part is important because it aborts the task if the parent process dies. It also guarantees the code before async/await has the same properties after you add the async call. For example, imagine you have this:
```elixir
x = Task.async(&heavy_fun/0)
y = some_fun()
Task.await(x) + y
```
As before, if heavy_fun/0 fails, the whole computation will fail, including the parent process. If you don't want the task to fail then you must change the heavy_fun/0 code in the same way you would achieve it if you didn't have the async call. For example, to either return {:ok, val} | :error results or, in more extreme cases, by using try/rescue. In other words, an asynchronous task should be thought of as an extension of a process rather than a mechanism to isolate it from all errors.

If you don't want to link the caller to the task, then you must use a supervised task with Task.Supervisor and call Task.Supervisor.async_nolink/2.

#### More on Task.Supervisor.async_nolink

Use it if task failure is likely, and should be handled in some way.
    
In case of task failure, caller receives `:DOWN` message:
`{:DOWN, ref, :process, _pid, _reason}`

```elixir
defmodule MyApp.Server do
  use GenServer

  # ...

  def start_task do
    GenServer.call(__MODULE__, :start_task)
  end

  # In this case the task is already running, so we just return :ok.
  def handle_call(:start_task, _from, %{ref: ref} = state) when is_reference(ref) do
    {:reply, :ok, state}
  end

  # The task is not running yet, so let's start it.
  def handle_call(:start_task, _from, %{ref: nil} = state) do
    task =
      Task.Supervisor.async_nolink(MyApp.TaskSupervisor, fn ->
        # ...
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
  def handle_info({:DOWN, ref, :process, _pid, _reason}, %{ref: ref} = state) do
    # Log and possibly restart the task...
    {:noreply, %{state | ref: nil}}
  end
end
```

`async_nolink` function requires the task supervisor to have :temporary as the :restart option (the default), as async_nolink/4 keeps a direct reference to the task which is lost if the task is restarted.
TODO: clarify if `which is lost if the SUPERVISOR is restarted` is true, fix docs