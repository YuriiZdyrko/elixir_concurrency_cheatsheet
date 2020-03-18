defmodule DP.Producer do
    use GenStage
  
    @moduledoc """
    Because this module is managed by DynamicSupervisor,
    it's going to be restarted after :do_exit_normal

    Since the Conusmer subscribed_to using {:via} tuple,
    we can easily resubscribe (subscribe_to_producer) after restart.
    """

    def start_link(name) do
      IO.inspect("producer_start: #{name}")
      GenStage.start_link(DP.Producer, name, name: via_tuple(name))
    end
  
    def init(name) do
      Process.sleep(100)
      DP.Consumer.subscribe_to_producer(via_tuple(name))
      {:producer, 0}
    end

    def via_tuple(name) do
        {:via, Registry, {DP.ProducerRegistry, name}}
    end

    def handle_info(:do_exit_normal, state) do
        IO.inspect("producer_exit(#{inspect self()}, :normal)")
        # Process.exit(self(), :normal)
        {:stop, :normal, state}
    end
  
    def handle_demand(demand, counter) when demand > 0 do
      events = Enum.to_list(counter..counter+demand-1)
      {:noreply, events, counter + demand}
    end
end