defmodule RateLimiter.Runner do
    alias A
    alias RateLimiter

    def run do
    {:ok, a} = GenStage.start_link(A, 0)
    {:ok, b} = GenStage.start_link(RateLimiter, :ok)

    # Ask for 10 items every 2 seconds
    GenStage.sync_subscribe(b, to: a, max_demand: 10, interval: 2000)
  end
end

defmodule A do
  @moduledoc """
  Producer that emits lists of sequential numbers
  """
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

    # Simulate slow demand handling
    # Process.sleep(:rand.uniform(10_000))
    
    # Emit variable number of events to 
    # see how Consumer handles this.
    # next_count = :rand.uniform(demand)
    # IO.inspect("Producer: demand #{demand} => events #{next_count}")
    # events = Enum.to_list(counter..counter+next_count-1)
    
    events = Enum.to_list(counter..counter+demand-1)
    IO.inspect(events, charlists: false)
    {:noreply, events, counter + demand}
  end
end

defmodule RateLimiter do
  @moduledoc """
  The trick is - Consumer manages Producers' pending demand, 
  instead of Producers doing this.
  It's done by storing 

  TODO: extend RateLimiter functionality to support :min_demand
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
    interval = opts[:interval] || 2000

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
    # Whenever we handle events, 
    # we bump "pending" for producer.
    # "ask_and_schedule" then will do GenStage.ask(from, NEW_PENDING) once
    producers = Map.update!(
      producers, 
      from,
      fn {pending, interval} ->

        IO.inspect("Consumer pend: #{inspect pending} next_pend: #{inspect pending + length(events)}")

        # pending is always 0 here, don't see the point...
        {pending + length(events), interval}
        
        # This results in accumulation of demand in Producer.
        # TODO: investigate
        # {10, interval}
      end
    )

    # Consume the events by printing them.
    Process.sleep(:rand.uniform(10_000)) # simulate actual work
    # IO.inspect(events, charlists: false)

    # A producer_consumer would return the processed events here.
    {:noreply, [], producers}
  end

  def handle_info({:ask, from}, producers) do
    IO.inspect("INFO :ask")
    # This callback is invoked by the Process.send_after/3 message below.
    {:noreply, [], ask_and_schedule(producers, from)}
  end

  defp ask_and_schedule(producers, from) do
    case producers do
      %{^from => {pending, interval}} ->
        # Ask for any pending events
        # Repeatedly asking same "from" for a 0 "pending" is safe.

        # TODO:
        # Find out why GenStage.ask(from, 0) is never called.
        # I am an idiot.
        # GenStage.ask(from, 0) is never called because
        # handle_events overrides pending sooner than 2000 msec interval
        IO.inspect("<---")
        print_time()
        IO.inspect("GenStage.ask:pending #{inspect pending}")
        GenStage.ask(from, pending)
        print_time()
        IO.inspect("--->")

        # And let's check again after interval
        IO.inspect(interval)
        Process.send_after(self(), {:ask, from}, interval)
        
        # Finally, reset pending events to 0
        Map.put(producers, from, {0, interval})
      %{} ->
        producers
    end
  end

  def print_time do
    IO.inspect(Time.utc_now)
  end
end