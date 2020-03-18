defmodule DP.Consumer do
    use GenStage

    @moduledoc """
    Is subscribed to Producers (subscribe_to_producer)
    with cancel: :transient.
    This means, that in case of Producer's (exit: :normal):
    - Consumer is NOT terminated
    - subscription to Proucer is cancelled
    """
  
    def start_link(_ignore) do
      # For simplicity we'll name our GenStage with __MODULE__
      GenStage.start_link(DP.Consumer, :ok, name: __MODULE__)
    end

    def subscribe_to_producer(producer) do
        IO.inspect("subscribe_to_producer #{inspect producer}")
        GenStage.sync_subscribe(
            __MODULE__,
            to: producer,
            min_demand: 2,
            max_demand: 5,
            cancel: :transient
        )
    end
  
    def init(:ok) do
      {:consumer, :state_doesnt_matter}
    end
  
    def handle_events(events, _from, state) do
      # Wait for a second
      Process.sleep(100)
  
      # Inspect the events.
      IO.inspect(events, charlists: false)
  
      # We are a consumer, so we would never emit items.
      {:noreply, [], state}
    end
end