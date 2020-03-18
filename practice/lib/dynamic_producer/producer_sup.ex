defmodule DP.ProducerSupervisor do
    @moduledoc """
    Manages producers, restarts them in case they fail.
    By default DynamicSupervisor allows max 3 restarts in 5 seconds.
    """
    
    # Automatically defines child_spec/1
    use DynamicSupervisor
    alias DP.{Producer, Consumer}
  
    def start_link(_ignore) do
      DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def start_dynamic_producer(name) do
      DynamicSupervisor.start_child(__MODULE__, {Producer, name})
    end
  
    @impl true
    def init(_arg) do
      DynamicSupervisor.init(strategy: :one_for_one)
    end
end