### Registry

A local, decentralized and scalable key-value process storage.

It allows developers to lookup one or more processes with a given key.

Keys types:
`:unique keys` - key points to 0 or 1 processes
`:duplicate keys` - key points to n processes

Different keys could identify the same process.

Usage:
- name lookups (using the :via option)
- associate value to a process (using the :via option)
- custom dispatching rules, or a pubsub implementation.

**Example 1:** Registration using `via` tuple
```elixir
{:ok, _} = Registry.start_link(keys: :unique, name: Registry.ViaTest)

VIA_no_value = 
    {:via, Registry, {Registry.ViaTest, "agent"}}
VIA_value = 
    {:via, Registry, {Registry.ViaTest, "agent", :hello}}

{:ok, _} = 
    Agent.start_link(fn -> 0 end, name: VIA_...)

Registry.lookup(Registry.ViaTest, "agent")

VIA_no_value
#=> [{agent_pid, nil}]

VIA_value
#=> [{agent_pid, :hello}]
```

**Example 2:**
- registration of `self()` process with `Registry.register`
- duplicate registration
- pub/sub using dispatch/3, enabling partitions for better performance in concurrent environments
```elixir
Registry
    .start_link(
        keys: :duplicate, 
        name: Registry.MyRegistry,
        partitions: System.schedulers_online()
    )
    => {:ok, _}
    
    .lookup(Registry.MyRegistry, "hello")
    => []
    
    .register(Registry.MyRegistry, "hello", :world)
    => {:ok, _}

    .lookup(Registry.MyRegistry, "hello")
    => [{self(), :world}]

    .register(Registry.MyRegistry, "hello", :another)
    => {:ok, _}

    .lookup(Registry.MyRegistry, "hello"))
    => [{self(), :another}, {self(), :world}]

    .dispatch(
        Registry.MyRegistry, 
        "hello", 
        fn entries ->
            for {pid, _} <- entries, 
            do: send(pid, {:broadcast, "world"})
        end
    )
    => :ok
```

### Functions
```elixir
child_spec([start_option()]) 
    :: Supervisor.child_spec()

start_link([start_option()]) 
    :: {:ok, pid} | {:error, term()}

start_option() ::
  {:keys, :unique | :duplicate}
  | {:name, registry}
  | {:partitions, pos_integer() \\ 1}
    # the number of partitions in the registry. 
  | {:listeners, [atom()]}
    # list of named processes which are notified of
    # :register and :unregister events. 
    # The registered process must be monitored by the
    # listener if the listener wants to be notified 
    # if the registered process crashes.
  | {:meta, [{meta_key, meta_value}]}
    # :meta - a keyword list of metadata to be 
    # attached to the registry.

:partitions Defaults to 1.
:listeners -
:meta - a keyword list of metadata to be attached to the registry.


register(registry, key, value)
    :: {:ok, pid} 
        | {:error, {:already_registered, pid}}

unregister(registry(), key()) 
    :: :ok
unregister_match(registry, key, pattern, guards \\ []) 
    :: :ok


lookup(registry, key) 
    :: [{pid, value}]
match(registry, key, match_pattern, guards) 
    :: [{pid, value}]
select(registry, spec)
    :: [term()]


dispatch(registry, key, mfa_or_fun, opts \\ [])
    :: :ok

count(registry) 
    :: count
count_match (registry, key, pattern, guards \\ []) 
    :: count

keys(registry, pid) 
    :: [key]

update_value(registry, key, f) 
    :: {new_value, old_value} | :error

meta(registry, key) 
    :: {:ok, meta_value} | :error
put_meta(registry, key, value)
    :: :ok
```
