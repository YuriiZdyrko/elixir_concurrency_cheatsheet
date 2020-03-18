defmodule DP.AppRunner do
    use GenServer

    alias DP.{Consumer, Producer, ProducerSupervisor}

    def start_link(_) do
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
    end

    def init(_) do
        Process.send(__MODULE__, :run, [])
        {:ok, nil}
    end

    def run do
        producer_name = :first
        
        ProducerSupervisor.start_dynamic_producer(producer_name)
        
        # This will kill both Producer and :transient Consumer
        # Process.exit(producer_pid, :kill)

        # This will not kill any process 
        # (exit(pid, :normal) from another process has no effect)
        # Process.exit(producer_pid, :normal)

        # This will kill Producer, not kill :transient Consumer
        # inside Producer process
        # Process.exit(self(), :normal)

        Process.send(__MODULE__, {:exit_producer_later, producer_name}, [])
    end

    def handle_info(:run, _) do
        run()
        {:noreply, nil}
    end
    
    def handle_info({:exit_producer_later, producer_name}, _state) do
        # Producer will:
        # - exit with :normal
        # - be restarted by DynamicSuppervisor
        #   (and resubscribed to a Consumer)
        #   ...
            # But if restart happens more than 3 times in 5 seconds 
            # (default :max_restarts = 3*5 seconds in DynamicSupervisor)
            # Registry.count(DP.ProducerRegistry) will become 0 forever,
            # as ProducerSupervisor will be restarted.

        pid = GenServer.whereis(Producer.via_tuple(producer_name))
        
        if (:rand.uniform(5) < 3 and pid) do
            # Exit :normal from another process is ignored!!!

            # IO.inspect("exit(#{inspect pid}, :normal")
            # Process.exit(pid, :normal)

            # This is why I call exit(self(), :normal) from Producer itself.
            Process.send(pid, :do_exit_normal, [])    
        end
        
        producer_count = Registry.count(DP.ProducerRegistry)
        IO.inspect("producer_count: #{producer_count}")
        
        IO.inspect([
            Process.whereis(DP.ProducerSupervisor),
            Process.whereis(DP.ConsumerSupervisor),
            Process.whereis(DP.Consumer),
            Process.whereis(DP.ProducerRegistry)
        ])

        Process.send_after(self(), {:exit_producer_later, producer_name}, 500, [])

        {:noreply, nil}
    end
end