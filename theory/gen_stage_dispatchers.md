## GenStage dispatchers

### GenStage.Dispatcher behaviour
This module defines the behaviour used by `:producer` and `:producer_consumer` to dispatch events.

GenServer has three built-in implementations:
`DemandDispatcher`, `BroadcastDispatcher`, `PartitionDispatcher`.

Implementation is chosen in Producer:
```elixir
def init(:ok) do
    {
        :producer, 
        state, 
        dispatcher: 
            GenStage.BroadcastDispatcher
            | {GenStage.BroadcastDispatcher, dispatcher_options()}
    }
end
```

Callbacks:
```elixir
init(opts)
subscribe(opts, from, state)
ask(demand, from, state)
dispatch(events, length, state)
cancel(from, state)
info(msg, state)
```

### GenStage.DemandDispatcher
A dispatcher that sends batches to the highest demand.

This is the default dispatcher used by GenStage. In order to avoid greedy consumers, it is recommended that all consumers have exactly the same maximum demand.

### GenStage.BroadcastDispatcher

A dispatcher that accumulates demand from all consumers before broadcasting events to all of them.
It guarantees that events are dispatched to all consumers without exceeding the demand of any given consumer.

Example with BroadcastDispatcher-specific `:selector` option:

```elixir
# Inside consumer's init/1
{
    :consumer, 
    :ok, 
    subscribe_to:
        [{
            producer, 
            # Consumers receive events, filtered by selector
            selector: fn %{key: key} -> 
                String.starts_with?(key, "foo-") 
            end
        }]
}
end
# or
GenStage.sync_subscribe(
    consumer,
    to: producer,
    selector: 
        fn %{key: key} ->
            String.starts_with?(key, "foo-") 
        end
)
```

### GenStage.PartitionDispatcher

A dispatcher that sends events according to partitions.

Keep in mind that, if partitions are not evenly distributed, a backed-up partition will slow all other ones.

```elixir
dispatcher_options() :: 
    partitions :: integer or list
    # 4 = partitions with keys 0, 1, 2, 3
    # 0..3 = same

    hash :: (event) => {event, partition_key}
    # function to hash event
    # example:
```

When subscribing to a GenStage with a partition dispatcher the `:partition` option is required.

```elixir
# Choose dispatcher inside producer's init/1
{
    :producer, 
    state, 
    dispatcher: {
        GenStage.PartitionDispatcher, 
        partitions: 0..3,
        hash: fn event -> 
            {
                event, 
                :erlang.phash2(
                    event, 
                    Enum.count(partitions)
                )
            }
        end
    }
}

# Inside consumer's init/1
{
    :consumer, 
    :ok, 
    subscribe_to: [{producer, partition: 0}]
}
# or
GenStage.sync_subscribe(
    consumer, 
    to: producer, 
    partition: 0
)
```