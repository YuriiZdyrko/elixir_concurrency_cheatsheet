## Supervisor behaviour

Supervisor = Child specification + Supervision options.

### Child specification

#### Creation
By `use GenServer`, `use Supervisor`, `use Task` `child_spec` callback is generated.
It returns child specification, to be used by Supervisors:

```elixir
child_spec().t :: %{
    id:
        term() \\ __MODULE__
    start:
        {m, f, a}
    restart:
        :permanent 
        | :temporary 
        | :transient 
    shutdown:
        :brutal_kill
        | timeout
        | :infinity
    type:
        :worker 
        | :supervisor
}
```

####  Usage in Supervisor
1. Without modification
```elixir
Supervisor.init([
    supervisor_child_spec()
], strategy: ...)
```
2. With some fields overridden
```elixir
Supervisor.init(
    [
        Supervisor.child_spec(supervisor_child_spec(), id: 1),
        Supervisor.child_spec(supervisor_child_spec(), id: 2)
    ], 
    strategy: ...
)
```

### child_spec:restart and exit reasons
```elixir
                    :normal  |  :shutdown, {:shutdown, term} | other
permanent_restart:  yes      |  yes                          | yes
temporary_restart:  no       |  no                           | no
transient_restart:  no       |  no                           | yes

exit_logged:        no       |  no                           | yes
linked_proc_exit:   no       |  yes*                         | yes*
```

yes* - restart with same reason, unless trapping exits

### child_spec:shutdown
Defaults: `:supervisor`-`:infinity`, `:worker`-`5000`

So if a Worker is trapping exits, it will receive `Process.exit(:shutdown)`, and will have 5000 to do cleanup, before being sent a `Process.exit(:kill)`.

### Supervision options
```elixir
# Examples for top-level or module-based Supervisors
Supervisor.start_link(children, options)
Supervisor.init(children, options)
```
```elixir
strategy:
    :one_for_one \\ default
    | :rest_for_one
    | :one_for_all
max_restarts: # if reached, supervisor exits with :shutdown reason
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

### Types

```elixir
supervisor_child_spec().t ::
    child_spec()
    | {module(), term()} 
    | module()

supervisor_init_opts().t ::
    {:strategy, strategy()}
    | {:max_restarts, non_neg_integer()}
    | {:max_seconds, pos_integer()}
```

### Functions

```elixir
start_link/2 # same as GenServer
start_link/3 # same as GenServer
```


```elixir
# Used inside init/1 callback
init(
    [supervisor_child_spec()], 
    supervisor_init_opts()
) :: {:ok, tuple()}
```

```elixir
stop(
    supervisor(), 
    reason :: term(), 
    timeout()
) :: :ok
```

```elixir
child_spec(supervisor_child_spec(), overrides) ::
  child_spec()

# supervisor.child_spec() is often used to pass spec id, 
# to be able to start multiple instances of same module.
# examples:
Supervisor.child_spec(
    { Stack, [:hello] }, 
    id: MyStack, 
    shutdown: 10_000
})
Supervisor.child_spec(
    {Agent, fn -> :ok end}, 
    id: {Agent, 1}
)
```

```elixir
count_children(supervisor()) :: %{
  specs: non_neg_integer(),
  active: non_neg_integer(),
  supervisors: non_neg_integer(),
  workers: non_neg_integer()
}
```

```elixir
which_children(supervisor()) :: [
    {
        term() | :undefined, = child_id
        child() | :restarting, = pid
        :worker | :supervisor,
        :supervisor.modules()
    }
]
```

```elixir
start_child(
    supervisor(), 
    supervisor_child_spec()
)
::  {:ok, child()}
    | {:ok, child(), info :: term()}
    | {:error, 
            {:already_started, child()} 
            | :already_present 
            | term()
    }
```

```elixir
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
```

```elixir
# Terminates a running child process
terminate_child(
    supervisor(), child_id
) 
::  :ok
    | {:error, :not_found}

```

```elixir
# Deletes specification for a non-running child process
delete_child(
    supervisor(), child_id
)
::  :ok 
    | {
        :error, 
        :not_found | :running | :restarting
    }
```
