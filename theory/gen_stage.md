## GenStage

Stages are used for:
- provide **back-pressure**
- leverage **concurrency**

Use `Task.async_stream` instead if both conditions are true:
- list to be processed is already in memory
- **back-pressure** is not needed

**Concurrency** in GenStage pipeline is achieved by having multiple Consumers for same Producer. Adding more Consumers allows to max out CPU and IO usage as necessary.

Producer implements **back-pressure** mechanism:
 - has it's own **demand** (sum of Consumers' demands)
 - emits to each Consumer `n` **events**, where `n <= consumer demand`. Dispatcher is used to send **events**.

Consumer <-> Producer is a **many-to-many** relationship.

#### Protocol details:
1. Consumers send to Producers:
- start subscription
- cancel subscription
- send demand for a given subscription

2. Producers send to Consumers:
- cancel subscription
  (used as confirmation of clients cancellations, or to cancel upstream demand)
- send events to given subscription

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
 --- EVENTS (downstream) --->
  [A]  --->  [B]  ---> [C]
 <--- DEMAND (upstream) ---  
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

### Asynchronous work and handle_subscribe

Consumer and ProducerConsumer first `handle_events/3`, and then send **demand** upstream. This means demand is sent synchronously by default.
There are two options to send demand asynchronously:

1. Manual:
- implement the `handle_subscribe/4` callback and return `{:manual, state}` instead of the default `{:automatic, state}`, 
- use `GenStage.ask/3` to send demand upstream when necessary. `:max_demand` and `:min_demand` should be manually respected.

2. Using ConsumerSupervisor:
ConsumerSupervisor module processes events asynchronously by starting a process for each event and this is achieved by manually sending demand to producers.

### Back-pressure

`handle_subscribe/4` + `manual` is also useful for implementing custom **back-pressure** mechanisms.

#### Default back-pressure mechanism
When data is sent between stages, it is done by a message protocol that provides back-pressure. - consumer subscribes to the producer. Each subscription has a unique reference.
- once subscribed, consumer may ask the producer for messages for the given subscription. A consumer must never receive more data than it has asked from a Producer.

A producer may have multiple consumers, where the demand and events are managed and delivered according to a GenStage.Dispatcher implementation.
A consumer may have multiple producers, where each demand is managed individually (on a per-subscription basis). See example below:

#### Example of custom back-pressure mechanism
Implement a consumer that is allowed to process a limited number of events per time interval:

```elixir
defmodule RateLimiter do
  @moduledoc """
  The trick is - Consumer manages Producers' pending demand, 
  instead of Producer doing this.
  There are 2 main pieces of puzzle:
  
  1. ask_and_schedule calls itself recursively with an interval:
    - GenStage.ask(from, pending) 
      -> trigger handle_events
    - resets pending to 0, which results in possible GenStage.ask(from, 0) repeated calls,
      but it's harmless, as handle_demand(0) is ignored by Producers.
    
  2. handle_events (triggered by GenStage.ask(from, pending))
    - gets new events
    - processes them
    - sets pending to length(events) 
      -> thanks to this ask_and_schedule will repeat 1-2 cycle
  """
  use GenStage

  def init(_) do
    # Our state will keep all producers and their pending demand
    {:consumer, %{}}
  end

  @doc """
  from() :: {pid(), subscription_tag()}
  The term that identifies a subscription associated with the corresponding producer/consumer.
  """
  def handle_subscribe(:producer, opts, from, _state = producers) do
    # We will only allow max_demand events every 5000 milliseconds
    pending = opts[:max_demand] || 1000
    interval = opts[:interval] || 5000

    # Register the producer in the state
    producers = Map.put(producers, from, {pending, interval})
    # Ask for the pending events and schedule the next time around
    producers = ask_and_schedule(producers, from)

    # Returns manual as we want control over the demand
    {:manual, producers}
  end

  def handle_cancel(_, from, producers) do
    # Remove the producers from the map on unsubscribe
    {:noreply, [], Map.delete(producers, from)}
  end

  def handle_events(events, from, producers) do
    # Bump the amount of pending events for the given producer
    producers = Map.update!(
      producers, 
      from, 
      fn {pending, interval} ->
        {pending + length(events), interval}
      end
    )

    # Consume the events by printing them.
    Process.sleep(:rand.uniform(10_000)) # simulate actual work
    IO.inspect(events)

    # A producer_consumer would return the processed events here.
    {:noreply, [], producers}
  end

  def handle_info({:ask, from}, producers) do
    # This callback is invoked by the Process.send_after/3 message below.
    {:noreply, [], ask_and_schedule(producers, from)}
  end

  defp ask_and_schedule(producers, from) do
    case producers do
      %{^from => {pending, interval}} ->
        # Ask for any pending events
        GenStage.ask(from, pending)
        # And let's check again after interval
        Process.send_after(self(), {:ask, from}, interval)
        # Finally, reset pending events to 0
        Map.put(producers, from, {0, interval})
      %{} ->
        producers
    end
  end
end
```

```elixir
{:ok, a} = GenStage.start_link(A, 0)
{:ok, b} = GenStage.start_link(RateLimiter, :ok)

# Ask for 10 items every 2 seconds
GenStage.sync_subscribe(b, to: a, max_demand: 10, interval: 2000)
```

### Functions

#### TODO: Group methods by meaning

#### Init

### Callbacks

Define/override child_spec:
```elixir
use GenStage, 
  restart: :transient, 
  shutdown: 10_000
```
Required callbacks:
`init/1` - choice between `:producer`, `:consumer`, `:producer_consumer` stages
`handle_demand/2` - `:producer` stage
`handle_events/3` - `:producer_consumer`, `:consumer` stages

```elixir
init(args) ::
  {:producer, state}
  | {:producer, state, [producer_option()]}
  | {:producer_consumer, state}
  | {:producer_consumer, state, [producer_consumer_option()]}
  | {:consumer, state}
  | {:consumer, state, [consumer_option()]}
  | :ignore
  | {:stop, reason :: any()}
```
```elixir
:init/1 options

:producer
  demand:
    :forward (default)
    # forward demand to the `handle_demand/2` callback. 
    
    :accumulate
    # accumulate demand until its mode 
    # is set to :forward via demand/2

# :accumulate is useful as a synchronization mechanism, 
# where the demand is accumulated until all consumers are subscribed. 

:producer and :producer_consumer
  :buffer_size
    10_000 (:producer default)
    :infinity (:producer_consumer default)
    # The size of the buffer to store events without demand.

  :buffer_keep \\ :last
    # whether the :first or :last entries should stay in buffer 
    # if :buffer_size is exceeded

  :dispatcher \\ GenStage.DemandDispatch
    DispatcherModule
    | {DispatcherModule, options}
    # the dispatcher responsible for handling demand

:consumer and :producer_consumer
  :subscribe_to
    [ProducerModule]
    | [{ProducerModule, options}]
```

```elixir
handle_call(request, from, state) ::
  {:reply, reply, [event], new_state}
  | {:noreply, [event], new_state}
  | {:stop, reason, reply, new_state}
  | {:stop, reason, new_state}

  {:reply, reply, [events], new_state}
    -> dispatch events (or buffer)
    -> send the response reply to caller
    -> continue loop with new state
  {:noreply, [event], state}
    -> dispatch events (or buffer)
    -> continue loop with new state
    -> manually send response with `GenStage.reply`
  {:stop, reason, new_state}
    -> stop the loop
    -> terminate is called with a reason and new_state
```

```elixir
handle_cast(request, state) ::
handle_info(message, state) ::

# required for :producer stage 
handle_demand(demand :: pos_integer(), state) ::

# required for :producer_consumer and :consumer stages
handle_events(events :: [event], from(), state) ::

  {:noreply, [event], new_state}
  | {:stop, reason, new_state}
  
  # {:noreply, [event], new_state}
  # -> dispatch or buffer events
  # -> continue loop with new state
```

```elixir
# Invoked in both producers and consumers when consumer subscribes to producer.

handle_subscribe(
  producer_or_consumer :: :producer | :consumer,
  subscription_options(),
  from(),
  state :: term()
) :: 
  {:automatic | :manual, new_state} 
  | {:stop, reason, new_state}

  {:automatic, new_state} (default)
    -> demand is sent automatically to producer

  {:manual, new_state}
    -> supported only by Consumers!
    -> send demand via ask(subscription_options(), demand)
```

```elixir
handle_cancel(
  cancellation_reason :: {
    :cancel # cancellation from GenStage.cancel/2 call
    | :down, # cancellation from an EXIT
    reason
  },
  from(),
  state
) ::
  {:noreply, [], new_state} \\ default
  | handle_cast_returns
```