defmodule DP.ConsumerSupervisor do
    use Supervisor
    alias DP.Consumer

    def start_link(_ignore) do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(_init_arg) do
        children = [
            Consumer
        ]

        Supervisor.init(children, strategy: :one_for_one)
    end
end