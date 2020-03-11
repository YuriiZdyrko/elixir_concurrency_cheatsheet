## Task

Execute function in a new process, monitored by, or linked to a caller.

It's better to spawn tasks with `Task.Supervisor`, instead of using Task.{start_link/1, async/3}
 
```elixir 
Task.{async/3, start_link/1} - link to caller
Task.{start/1} - no link to caller

Task.{async/3} - reply expected
Task.{start/1, start_link/1} - no reply expected
```

`Task.async/3` can be handed to:
- `Task.await/2` error after timeout
- `Task.yield/2` - can be invoked again after timeout

```elixir
task = Task.async(fn -> do_some_work() end)
res = do_some_other_work()
res + Task.await(task)
```

#### Module-based
Limitation: can't be awaited on.

```elixir
Supervisor.start_link(
    [
        {MyTask, arg}
    ], 
    strategy: :one_for_one
)

defmodule MyTask do
  use Task # default restart: :temporary
           # (never restarted)

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(arg) do
    # ...
  end
end
```
