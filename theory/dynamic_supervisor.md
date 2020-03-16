## DynamicSupervisor behaviour

DynamicSupervisor is started without Child Specification.
Children are started on-demand.

Module-less:
```elixir
children = [
    {
        DynamicSupervisor, 
        strategy: :one_for_one, 
        name: MyApp.DynamicSupervisor
    },
    ...
]

Supervisor.start_link(children, init_option())
```

Module-based:
```elixir
defmodule MyApp.DynamicSupervisor do
  # Automatically defines child_spec/1
  use DynamicSupervisor

  def start_child(foo, bar, baz) do
    spec = {MyWorker, foo: foo, bar: bar, baz: baz}
    DynamicSupervisor.start_child(
        __MODULE__, 
        spec
    )
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(
        __MODULE__, 
        init_arg, 
        name: same_as_gen_server
    )
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(init_option())
  end
end
```


```elixir
init_option() ::
  {:strategy, strategy()}
  | {:max_restarts, non_neg_integer()}
  | {:max_seconds, pos_integer()}
  | {:max_children, non_neg_integer() \\ :infinity}
  | {:extra_arguments, [term()]}
```

Where extra_arguments is `init` arguments, that will be prepended to `start_child` arguments for each started child.

### Functions
```
child_spec/1
count_children/1
init/1
start_child/2
start_link/1
start_link/3
stop/3
terminate_child/2
which_children/1
```

```elixir
start_child(
  Supervisor.supervisor(),
  Supervisor.child_spec()
  | {module(), args}
  | module()
) 
::  {:ok, child()}
    | {:ok, :undefined} (if child process init/1 returns :ignore)
    | {:error, :max_children}
    | {:error, error}

terminate_child(
    Supervisor.supervisor(), pid()
)
::  :ok 
    | {:error, :not_found}

which_children(supervisor()) 
:: [
    {
        :undefined = child_id
        child() | :restarting = pid
        :worker | :supervisor
        :supervisor.modules()
    }
    ...
]
```