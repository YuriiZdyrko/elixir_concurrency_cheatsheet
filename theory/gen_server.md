## GenServer

used for:
- mutable state (by abstracting receive loop)
- enabling concurrency
- isolating failures

#### GenServer.start_link
``` elixir
GenServer
    start_link(
        _,
        options:
            name: 
                atom
                | {:global, term}
                | {:via, module, name}
            timeout:
                msecs \\ :infinity
    )
```

#### GenServer.call
```elixir
GenServer
    call(
        server, 
        request, 
        timeout \\ 5000
    ) :: response
```

#### GenServer.cast
```elixir
GenServer
    cast(
        server,
        request
    ) :: :ok
```

#### GenServer.reply
```elixir
GenServer
    reply(pid, term) 
        :: :ok
``` 
Can be used instead of {:reply, _, _} inside `handle_call`.

```elixir
def handle_call(:reply_in_one_second, from, state) do
  Process.send_after(self(), {:reply, from}, 1_000)
  {:noreply, state}
end

def handle_info({:reply, from}, state) do
  GenServer.reply(from, :one_second_has_passed)
  {:noreply, state}
end
```
`GenServer.reply` can even be done from different process.

#### GenServer.stop
Synchronously stops server with given reason
Normal reasons (no error logged): 
    `:normal
    | :shutdown
    | {:shutdown, term}`
```
GenServer
    stop(
        server, 
        reason \\ :normal, 
        timeout \\ :infinity
    ) :: :ok
```

#### GenServer timeout mechanism:
:timeout message will be sent if no handle_* is invoked 
in timeout msecs.

Setup: add timeout option to:
``` elixir
GenServer
    init
        {:ok, _, timeout}
GenServer
    handle_* :: {_, _, timeout}


GenServer
    handle_info(:timeout, _)
```

Because a message may arrive before the timeout is set, even a timeout of 0 milliseconds is not guaranteed to execute. 
To take another action immediately and unconditionally, use a `:continue` instruction + `handle_continue` callback.

#### GenServer.handle_continue
**Asynchronous initialization can cause a race condition:**
https://medium.com/@tylerpachal/introduction-to-handle-continue-in-elixir-and-when-to-use-it-53ba5519cc17

``` elixir
GenServer
    init
        {:ok, state, {:continue, :more_init}}

GenServer
    handle_call(:work, _, state)
        :: {
            :reply, 
            _, 
            state, 
            {:continue, :more_work}
        }
end

GenServer
    handle_continue(:more_init, state)
        :: {:noreply, new_state}
```

handle_continue doesn't block caller process, 
and also ensures nothing gets in front of it in a GenServer's mailbox.

`handle_call` + `handle_continue` = respond + immediate handle_info.
`init` + `handle_continue` = init + immediate handle_info.

### Callbacks
`:reply, :noreply, :stop, :continue` are **instructions**
`from()` = `{pid(), tag :: term()}`

#### handle: init
```elixir
init(init_arg :: term()) ::
      {:ok, state}
    | {
        :ok, 
        state, 
        timeout() | :hibernate | {:continue, term()}
    }
    | :ignore
    | {:stop, reason :: any()}
```
#### handle: call
Invoked to handle synchronous call/3 messages.

```elixir
handle_call(
    request :: term(), 
    from(), 
    state :: term()
) ::  {:reply, reply, new_state}
    | {:reply, 
        reply, 
        new_state, 
        timeout() | :hibernate | {:continue, term()}
    }
    | {:noreply, new_state}
    | {
        :noreply, 
        new_state, 
        timeout() | :hibernate | {:continue, term()}
    }
    | {:stop, reason, reply, new_state}
    | {:stop, reason, new_state}
```
#### handle: cast
Invoked to handle asynchronous cast/2 messages.

```elixir
handle_cast(
    request :: term(), 
    state :: term()
) ::  {:noreply, new_state}
    | {:noreply, 
        new_state, 
        timeout() | :hibernate | {:continue, term()}
    }
    | {:stop, reason :: term(), new_state}
```
#### handle: info
```elixir
handle_info(
    msg :: :timeout | term(), 
    state :: term()
) :: return_same_as_handle_cast()
```
#### handle: continue
```elixir
handle_continue(
    continue :: term(), 
    state :: term()
) :: return_same_as_handle_cast()
```
### handle: terminate
Invoked when the server is about to exit. It should do any cleanup required.
```elixir
terminate(reason, state :: term()) 
    :: term()
when reason: 
    :normal | :shutdown | {:shutdown, term()}
```
`reason` is exit reason.

It's called if any of callbacks (except `init`):
- returns a `:stop` instruction
- raises or returns invalid value
- traps exits and parent process sends an exit signal 
(probably not important if part of Supervision tree)
+ If GenServer.stop or Kernel.exit is called

Terminate is not invoked for `System.halt(0)`

If part of Supervision tree, during tree shutdown, GenServer will receive an exit reason, depending on `child_spec` `shutdown` option:
-  for `:brutal_kill` option
  `:kill` (terminate not called)
-  for `{:shutdown, timeout}` option
  `:shutdown` (terminate called with time limit)

So it's not reliable...

Important clean-up rules belong in separate processes either by use of `monitoring` or by `link + trap_exit` (as in Supervisors)

### Process monitoring
``` elixir
Process
    monitor

GenServer
    handle_info({:DOWN})
```

```console
2nd parameter is timeout

:sys.get_state/2
:sys.get_status/2 - see :sys.process_status section
:sys.statistics/3 - see :sys.statistics section
:sys.no_debug/2

:sys.suspend/2 
:sys.resume/2
```

### :sys.process_status
```console
{:status, #PID<0.127.0>, {:module, :gen_server},
 [
   [
     "$initial_call": {:erl_eval, :"-expr/5-fun-3-", 0},
     "$ancestors": [#PID<0.104.0>, #PID<0.76.0>]
   ],
   :running,
   #PID<0.104.0>,
   [statistics: {{{2020, 3, 6}, {14, 1, 44}}, {:reductions, 251}, 1, 1}],
   [
     header: 'Status for generic server <0.127.0>',
     data: [
       {'Status', :running},
       {'Parent', #PID<0.104.0>},
       {'Logged events', []}
     ],
     data: [{'State', 4}]
   ]
 ]}
```

### Process statistics using :sys.statistics
```console
{:ok, pid} = Agent.start_link(fn -> 1 end)
Agent.update(pid, fn state -> state + 1 end)
:sys.statistics pid, :get

=> {:ok, :no_statistics}

:sys.statistics pid, :true
Agent.update(pid, fn state -> state + 1 end)
:sys.statistics pid, :get

=> {:ok,
 [
   start_time: {{2020, 3, 6}, {14, 1, 44}},
   current_time: {{2020, 3, 6}, {14, 1, 52}},
   reductions: 120,
   messages_in: 1,
   messages_out: 1
 ]}
```