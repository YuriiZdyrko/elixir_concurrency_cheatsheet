## GenStage

Stages are used for:
- provide **back-pressure**
- leverage **concurrency**

Use `Task.async_stream` instead if both conditions are true:
- list to be processed is already in memory
- **back-pressure** is not needed

**Concurrency** in GenStage pipeline is achieved by having multiple Consumers for same Producer.

Producer implements **back-pressure** mechanism:
 - has it's own **demand** (sum of Consumers' demands)
 - emits to each Consumer `n` **events**, where `n <= consumer demand`. Dispatcher is used to send **events**.

Consumer <-> Producer is a **many-to-many** relationship.

Consumer max and min demand is often set on subscription:
- `:max_demand` - max amount of events that must be in flow 
- `:min_demand` - minimum threshold to trigger for more demand. 
 
#### Example: 
`:max_demand` = 1000, `:min_demand` = 750. 
Possible Consumer actions:
- demand 1000 events
- receive 1000 events
- process at least 250 events
- ask for more events
```
# Events flow downstream, demand upstream.
 --- EVENTS --->
[A] -> [B] -> [C]
 <--- DEMAND ---
```

```elixir
defmodule A do
  use GenStage

  def start_link(number) do
    GenStage.start_link(A, number, name: __MODULE__)
  end

  def init(counter) do
    {:producer, counter}
  end

  def handle_demand(demand, counter) when demand > 0 do
    # If the counter is 3 and we ask for 2 items, we will
    # emit the items 3 and 4, and set the state to 5.
    events = Enum.to_list(counter..counter+demand-1)
    {:noreply, events, counter + demand}
  end
end
```

```elixir
# ProducerConsumers act as a buffer. 
# Getting the proper demand values is important:
# too small buffer may make the whole pipeline slower
# too big buffer may unnecessarily consume memory

defmodule B do
  use GenStage

  def start_link(multiplier) do
    GenStage.start_link(B, multiplier)
  end

  def init(multiplier) do
    # Manual subscription
    # {:producer_consumer, multiplier}
    # + GenStage.sync_subscribe(b, to: a)

    # Automatic subscription, relies on named Producer process.
    # Consumer crash will automatically re-subscribe it
    {
        :producer_consumer, 
        multiplier, 
        subscribe_to: [{A, max_demand: 10}]
    }
  end

  def handle_events(events, _from, multiplier) do
    events = Enum.map(events, & &1 * multiplier)
    {:noreply, events, multiplier}
  end
end
```

```elixir
defmodule C do
  use GenStage

  def start_link(_opts) do
    GenStage.start_link(C, :ok)
  end

  def init(:ok) do
    {:consumer, :the_state_does_not_matter}
  end

  def handle_events(events, _from, state) do
    # Wait for a second.
    Process.sleep(1000)

    # Inspect the events.
    IO.inspect(events)

    # We are a consumer, so we would never emit items.
    {:noreply, [], state}
  end
end
```

#### Subscription

1. Manual subscription (no Supervision)
```elixir
subscription
{:ok, a} = A.start_link(0) # starting from zero
{:ok, b1} = B.start_link(2) # multiply by 2
{:ok, b2} = B.start_link(2)
{:ok, c} = C.start_link([]) # state does not matter

# Typically subscription goes from bottom to top:
GenStage.sync_subscribe(c, to: b)
GenStage.sync_subscribe(b1, to: a)
GenStage.sync_subscribe(b2, to: a)
```

2. Automatic subscription during Consumer's `init`
```elixir
children = [
  {A, 0},
  Supervisor.child_spec({B, [2]}, id: :c1),
  Supervisor.child_spec({B, [2]}, id: :c2)
  C
]

# Termination of Producer A causes termination of all Consumers. 
#To avoid too many failures in a short interval:
# - use `:rest_for_one`
# - put Consumers under separate Supervisor
# - use ConsumerSupervisor (best approach)

Supervisor.start_link(children, strategy: :rest_for_one)
```

#### Buffering

1. Buffering events.
=> Buffer events until a consumer is available.
Use `:buffer_size \\ 10_000` option in Producer `init` callback.

2. Buffering demand.
Consumers ask producers for events that are not yet available
=> buffer the consumer demand until events arrive


### Example of manual control over dispatch

If events are sent without corresponding demand, they will wait in Producer's internal buffer. 
By default max size of internal buffer is 10_000, and `:buffer_size` error is thrown if it's exceeded.

**Solution**:
We manage buffer manually, and don't let Producer dispatch events without corresponding demand.
By managing queue and demand, we can control:
- how to behave when there are no consumers
- how to behave the queue grows too large
- ...
Only case internal buffer may be used - if Consumer crashes without consuming all data.

```elixir
defmodule QueueBroadcaster do
  @moduledoc """
  If events, but no demand -> buffer events
  If demand, but no events -> buffer demand
  """

  use GenStage

  @doc "Starts the broadcaster."
  def start_link() do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Sends an event and returns only after the event is dispatched."
  def sync_notify(event, timeout \\ 5000) do
    GenStage.call(__MODULE__, {:notify, event}, timeout)
  end

  ## Callbacks

  def init(:ok) do
    # {:queue.new, 0} - {events buffer, pending demand}
    {:producer, {:queue.new, 0}, dispatcher: GenStage.BroadcastDispatcher}
  end

  @doc """
  Incoming event:
  - add event to events queue in state
  - try to dispatch events
  """
  def handle_call({:notify, event}, from, {queue, pending_demand}) do
    queue = :queue.in({from, event}, queue)
    dispatch_events(queue, pending_demand, [])
  end

  @doc """
  Incoming demand:
  - increase pending demand in state
  - try to dispatch events
  """
  def handle_demand(incoming_demand, {queue, pending_demand}) do
    dispatch_events(queue, incoming_demand + pending_demand, [])
  end

  @doc """
  Pending demand = 0 

  => Dispatch events (demand end reached)
  """
  defp dispatch_events(queue, 0, events) do
    {:noreply, Enum.reverse(events), {queue, 0}}
  end

  @doc """
  Pending demand > 0
   
  => Recursively build events
  if (not (empty? queue))
    :: dispatch_events(queue -- e, demand - 1, [e | events])
  
    => Dispatch events (queue end reached)
    if (empty? queue) # recursion stop condition
      :: {:noreply, events, new_state = {queue, demand}}
    
  """
  defp dispatch_events(queue, demand, events) do
    case :queue.out(queue) do
      {{:value, {from, event}}, queue} ->
        # TODO: understand why reply is here
        GenStage.reply(from, :ok)
        dispatch_events(queue, demand - 1, [event | events])
      {:empty, queue} ->
        {:noreply, Enum.reverse(events), {queue, demand}}
    end
  end
end
```

```elixir
defmodule Printer do
  use GenStage

  @doc "Starts the consumer."
  def start_link() do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    # Starts a permanent subscription to the broadcaster
    # which will automatically start requesting items.
    {:consumer, :ok, subscribe_to: [QueueBroadcaster]}
  end

  def handle_events(events, _from, state) do
    for event <- events do
      IO.inspect {self(), event}
    end
    {:noreply, [], state}
  end
end
```

```elixir
# Demo

# Start the producer
QueueBroadcaster.start_link()

# Start multiple Printers (each sends it's demand to QueueBroadcaster)
Printer.start_link()
Printer.start_link()
Printer.start_link()

QueueBroadcaster.sync_notify(:hello_world)

# With [buffered demand] and [not empty queue],
# => QueueBroadcaster dispatches event to each Printer
```