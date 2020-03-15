## ConsumerSupervisor behaviour

A supervisor that starts children as events flow in
Can be used as the consumer in a GenStage pipeline.

Can be attached to a producer by returning `:subscribe_to` from `init/1` or explicitly with `GenStage.sync_subscribe/3` and `GenStage.async_subscribe/2`.

Once subscribed, the supervisor will:
- ask the producer for `:max_demand events` 
- start child processes per event as events arrive
  (event is appended to the arguments in the child specification)
- as child processes terminate, the supervisor will accumulate demand and request more events after `:min_demand` is reached

ConsumerSupervisor is similar to a pool, except a child process is started per event. 
`:min_demand` < `amount of concurrent children per producer` < `:max_demand`.

### Example

```elixir
defmodule Consumer do
  use ConsumerSupervisor

  def start_link(arg) do
    ConsumerSupervisor.start_link(__MODULE__, arg)
  end

  def init(_arg) do
    # Note: By default child.restart = :permanent
    # ConsumerSupervisor supports only :termporary or :transient
    children = [%{
        id: Printer, 
        start: {Printer, :start_link, []}, 
        restart: :transient
    }]
    opts = [
        strategy: :one_for_one, 
        subscribe_to: [{Producer, max_demand: 50}]
    ]
    ConsumerSupervisor.init(children, opts)
  end
end

defmodule Printer do
  def start_link(event) do
    # Note: this function must:
    # - return the format of {:ok, pid}
    # - like all children started by a Supervisor, 
    #   the process must be linked back to the supervisor
    # Task.start_link/1 satisfies these requirements
    Task.start_link(fn ->
      IO.inspect({self(), event})
    end)
  end
end
```

### Callbacks

```elixir
init_options() :: [
    max_restarts \\ 3,
    max_seconds \\ 5,
    subscribe_to: 
        [Producer]
        | [{Producer, max_demand: 20, min_demand: 10}]
        # [{Producer, subscription_options().t}]
]

init(args) ::
  {:ok, [:supervisor.child_spec()], init_options()} 
  | :ignore
```

### Functions

```elixir
# Supervisor
init(children, init_options()) # For module based supervisor
start_link(mod, args) # For module based supervisor
start_link(children, init_options()) # For in-place supervisor

# Children
start_child(supervisor, child_args)
terminate_child(supervisor, pid)
count_children(supervisor)
which_children(supervisor)
```
