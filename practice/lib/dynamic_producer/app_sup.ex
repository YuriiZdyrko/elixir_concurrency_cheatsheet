defmodule DP.AppSupervisor do
    @moduledoc """
    Let it crash part: sometimes ProducerSupervisor will fail,
    because of too frequent restarts of Producer
    (caused by :exit_producer_later) in app_runner.ex.

    But we have here strategy: :one_for_all,
    so entire app gets restarted!

    To see dead of ProducerSupervisor, change strategy: :one_for_one,
    observe in console:
    [#PID<0.207.0>, #PID<0.208.0>, #PID<0.209.0>, #PID<0.205.0>]
    ...
    [#PID<0.218.0>, #PID<0.208.0>, #PID<0.209.0>, #PID<0.205.0>]
    First pid (ProducerSupervisor) has changed
    """

    use Supervisor
    alias DP.ProducerSupervisor
    alias DP.ConsumerSupervisor

    def start_link(_ignore) do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(_init_arg) do
        children = [
            {Registry, 
                keys: :unique, 
                name: DP.ProducerRegistry
            },
            ProducerSupervisor,
            ConsumerSupervisor,
            DP.AppRunner
        ]

        Supervisor.init(children, strategy: :one_for_one)
    end
end