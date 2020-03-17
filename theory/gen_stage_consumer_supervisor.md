## ConsumerSupervisor behaviour

A supervisor that starts children as events flow in
Can be used as the consumer in a GenStage pipeline.
It's called ConsumerSupervisor because it acts as a Consumer (has a subscribe_to option) and is not intended to supervise Consumers.
Producers, Task or other OTP modules can be started from it.

Can be attached to a producer by returning `:subscribe_to` from `init/1` or explicitly with `GenStage.sync_subscribe/3` and `GenStage.async_subscribe/2`.

Once subscribed, the supervisor will:
- ask the producer for `:max_demand events` 
- start child processes per event as events arrive
  (event is appended to the arguments in the child specification)
- as child processes terminate, the supervisor will accumulate demand and request more events after `:min_demand` is reached

Children must exit after their work is done, otherwise new children can't be started. 
This means that {:stop, :normal, state} should be done inside children!

ConsumerSupervisor is similar to a pool, except a child process is started per event. 
`:min_demand` < `amount of concurrent children per producer` < `:max_demand`.

### Example

```elixir
defmodule Printer.ConsumerSupervisor do
  use ConsumerSupervisor

  def start_link(arg), do:
    ConsumerSupervisor.start_link(__MODULE__, arg)

  def init(_arg), do:
    # ConsumerSupervisor supports only :termporary or :transient restart
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
```
```elixir
defmodule Printer do
  def start_link(event), do:
    Task.start_link(fn -> IO.inspect({self(), event}) end)
end
```

`start_link/1` function of ConsumerSupervisor's child must:
- return the format of {:ok, pid}
- like all children started by a Supervisor, the process must be linked back to the supervisor

To make it clear, ConsumerSupervisor can have ANY OTP module as child.
For example a ChildPrinter could instantiate another ConsumerSupervisor using `start_link` inside it's `init` callback. This would create 2-level ConsumerSupervisor tree. Freedom!

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
