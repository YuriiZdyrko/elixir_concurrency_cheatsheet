## Process

Conveniences for working with processes.

```elixir
# spawn_options().t
Fun = function()
Options = [spawn_opt_option()]
priority_level() = low | normal | high | max
max_heap_size() =
    integer() >= 0 |
    {size => integer() >= 0,
      kill => boolean(),
      error_logger => boolean()}
message_queue_data() = off_heap | on_heap
spawn_opt_option() =
    link | monitor |
    {priority, Level :: priority_level()} |
    {fullsweep_after, Number :: integer() >= 0} |
    {min_heap_size, Size :: integer() >= 0} |
    {min_bin_vheap_size, VSize :: integer() >= 0} |
    {max_heap_size, Size :: max_heap_size()} |
    {message_queue_data, MQD :: message_queue_data()}
```

```elixir
# Process.info(pid) (:erlang.process_info/1)
[
  current_function: {:gen_server, :loop, 7},
  initial_call: {:proc_lib, :init_p, 5},
  status: :waiting,
  message_queue_len: 0,
  links: [],
  dictionary: [
    "$initial_call": {:erl_eval, :"-expr/5-fun-3-", 0},
    "$ancestors": [#PID<0.153.0>, #PID<0.75.0>]
  ],
  trap_exit: false,
  error_handler: :error_handler,
  priority: :normal,
  group_leader: #PID<0.64.0>,
  total_heap_size: 233,
  heap_size: 233,
  stack_size: 11,
  reductions: 64,
  garbage_collection: [
    max_heap_size: %{error_logger: true, kill: true, size: 0},
    min_bin_vheap_size: 46422,
    min_heap_size: 233,
    fullsweep_after: 65535,
    minor_gcs: 0
  ],
  suspending: []
]
```

#### Functions
```elixir
# Spawn/exit/hybernate
spawn(fun, spawn_options()) 
| spawn(m, f, a, spawn_options())
exit(pid, reason)*
alive?(pid)
hibernate(m, f, a)

# Flag
flag(flag, value) | flag(pid, flag, value)

# Send
send(dest, msg, options)
send_after(dest, msg, time, opts \\ [])

# Link to calling process
link(pid_or_port)
unlink(pid_or_port)

# Monitor from calling process
monitor(item)
demonitor(monitor_ref, options \\ [])

# Registration
register(pid_or_port, name)
unregister(name)
registered() :: [name]
whereis(name) :: pid | nil

# send_after/3 timers
read_timer(timer_ref)
cancel_timer(timer_ref, options \\ [])

# Debugging
sleep(timeout)
info(pid)
list() # list of all running PIDs
```

### Importance of exiting with :normal
* `Process.exit(pid, :normal)` will be ignored if pid != self()
This is preferred approach:
```elixir 
  # In caller process
  Process.send(pid, :exit_normal, [])
  +
  # In stopped implementation module
  handle_info(:exit_normal)
    {stop, :normal, state}
```
Exit :normal is especially common for marking as done children, started by dynamic supervisors.
Supervisors and DynamicSupervisors in this case will do whatever is their :strategy.
Or for ConsumerSupervisor - will be able to continue to process events.