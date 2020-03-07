### Supervisor = Child specification + Supervision options

### Child specification
```elixir
%{
    id:
        term() \\ __MODULE__
    start:
        {m, f, a}
    restart:
        :permanent (always restart)
        | :temporary (never restart)
        | :transient 
    shutdown:
        :brutal_kill
        | timeout
        | :infinity
}
| {Stack, [:hello]}
| Stack
```

**Restart transient**
No restart if exit reason:
`:normal, :shutdown, {:shutdown, term}`
Propagate to linked processes if exit reason not
`:normal`

**Default shutdown valuess**
`:infinity` for Supervisors
`5000` for Workers

So if a Worker is trapping exits, it will receive `Process.exit(:shutdown)`, and will have 5000 to do cleanup, before being sent a `Process.exit(:kill)`.

**Override child_spec outside implementation module**
```elixir
Supervisor.child_spec(
    {Stack, [:hello]}, 
    id: 1, 
    shutdown: 10_000
)
```

### Supervision options
Used for top-level or module-based Supervisors:
```
Supervisor.start_link(children, options)
Supervisor.init(children, options)
```
```elixir
strategy:
    :one_for_one
    | :rest_for_one
    | :one_for_all
max_restarts:
    count \\ 3
max_seconds:
    count \\ 5
name: 
    same_as_gen_server
```

### Module-based configuration
**Encapsulate Worker's configuration inside module**
```elixir
# Automatically defines child_spec/1
use GenServer, restart: :transient
```

**Encapsulate Supervisor's configuration inside module**
```elixir
defmodule MyApp.Supervisor do
  # Automatically defines child_spec/1
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(
        __MODULE__, 
        init_arg, 
        name: __MODULE__
    )
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Stack, [:hello]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```


## Functions
```
child_spec/2
count_children/1
delete_child/2
init/2
restart_child/2
start_child/2
start_link/2
start_link/3
stop/3
terminate_child/2
which_children/1
```

### Supervisor

```elixir
stop(
    supervisor(), 
    reason :: term(), 
    timeout()
) :: :ok

count_children(supervisor()) :: %{
  specs: non_neg_integer(),
  active: non_neg_integer(),
  supervisors: non_neg_integer(),
  workers: non_neg_integer()
}

which_children(supervisor()) :: [
    {
        term() | :undefined, = child_id
        child() | :restarting, = pid
        :worker | :supervisor,
        :supervisor.modules()
    }
]
```

### Supervisor children

```elixir
start_child(
    supervisor(), 
    :supervisor.child_spec()
    | {module(), term()} 
    | module()
)
::  {:ok, child()}
    | {:ok, child(), info :: term()}
    | {:error, 
            {:already_started, child()} 
            | :already_present 
            | term()
    }

restart_child(
    supervisor(), child_id
) 
::  {:ok, child()} 
    | {:ok, child(), term()} 
    | {:error, :not_found 
                | :running 
                | :restarting 
                | term()
    }


// Terminates a running child process
terminate_child(
    supervisor(), child_id
) 
::  :ok
    | {:error, :not_found}


// Deletes specification for a non-running child process
delete_child(
    supervisor(), child_id
)
::  :ok 
    | {
        :error, 
        :not_found | :running | :restarting
    }
```
