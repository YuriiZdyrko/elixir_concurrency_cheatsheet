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
  import IEx

  def start_link(number) do
    GenStage.start_link(A, number, name: __MODULE__)
  end

  def init(counter) do
    {:producer, {counter, 0}}
  end

  # To make demand cumulative, store it in state.
  # This way following happens:
  # Consumer demands 10
  # Producer returns 8
  # Consumer demands 8 (demand is 8 + 2 prev_demand)
  # Producer returns 10
  def handle_demand(demand, {counter, prev_demand}) do
    demand = if (demand == 1000), do: 0, else: demand
    
    # IEx.pry()
    # If the counter is 3 and we ask for 2 items, we will
    # emit the items 3 and 4, and set the state to 5.

    # Simulate slow demand handling
    Process.sleep(:rand.uniform(500))
    
    # Emit variable number of events to see how Consumer handles this.
    next_count = :rand.uniform(demand + prev_demand)
    
    events = Enum.to_list(counter..counter+next_count-1)
    
    # events = Enum.to_list(counter..counter+demand-1)
    
    result = {
      :noreply, 
      events, 
      {counter + next_count, demand + prev_demand - next_count}
    }

    IO.inspect("P: demand: #{inspect demand}")
    IO.inspect("P: prev_demand: #{inspect(prev_demand)}")
    IO.inspect("P: events: #{inspect(length(events))}")

    result
  end
end

defmodule RateLimiter do
  @moduledoc """
  The trick is - Consumer manages Producers' pending demand, 
  instead of Producers doing this.
  It's done by keeping Producers' demand inside Consumers state.

  There's nothing interesting here.
  Just a lot of trial and errors.
  """
  use GenStage
  import IEx

  @min_demand 5
  @max_demand 10

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
    producers = Map.put(producers, from, {pending, pending, interval})
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
      fn {pending, unsatisfied_demand, interval} ->
        # pending is always 0 here, don't see the point...
        diff = max(unsatisfied_demand - length(events), 0)
        {next_pending, new_unsatisfied_demand} = if diff < @min_demand do
          {@max_demand - diff, @max_demand}
        else
          # :min_demand not reached yet, ask for 0, which will
          # utilize prev_demand in Producers
          {0, diff}
        end
        
        # IEx.prsy()
        result = {next_pending, new_unsatisfied_demand, interval}
        IO.inspect("Consumer% #{inspect result}")

        # `ask_and_schedule` will be called repeatedly with interval "interval"
        # to check if this result has some "pending"
        result
        
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
    # This callback is invoked by the Process.send_after/3 message below.
    {:noreply, [], ask_and_schedule(producers, from)}
  end

  defp ask_and_schedule(producers, from) do
    case producers do
      %{^from => {pending, unsatisfied_demand, interval}} ->
        # Ask for any pending events
        # Repeatedly asking same "from" for a 0 "pending" is safe.

        # TODO:
        # Find out why GenStage.ask(from, 0) is never called.
        # I am an idiot.
        # GenStage.ask(from, 0) is never called because
        # handle_events overrides pending sooner than 2000 msec interval
        # if (pending > 0) do
        IO.inspect("C: #{inspect pending}")
        GenStage.ask(from, pending)
        # end

        # And let's check again after interval
        # IO.inspect(interval)
        Process.send_after(self(), {:ask, from}, interval)
        
        # Finally, reset pending events to 0
        {_pending, unsatisfied_demand, _interval} = Map.fetch!(producers, from)
        
        Map.put(producers, from, {1000, unsatisfied_demand, interval})
      %{} ->
        producers
    end
  end

  def print_time do
    IO.inspect(Time.utc_now)
  end
end