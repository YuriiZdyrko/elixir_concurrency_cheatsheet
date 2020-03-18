defmodule Facebook.AccountsProducer do
  @moduledoc """
  Initialization: singleton
  Registration: local (name: :facebook_accounts_producer)

  Dispatching:
  - using @repopulate_state_interval, fetch account_ids list fro Database
  Dispatch list of account_ids

  Buffering: 
  - not needed as Producer asks for more events, only if queue is nearly empty.

  Facebook.AccountsProducer < demand < Facebook.AccountsConsumerSupervisor

  # Termination
  AccountsProducer and AccountsConsumerSupervisor 
  are the only Stages that never go down
  """

  use GenStage

  @repopulate_state_interval 1000 * 60

  def start_link do
    GenStage.start_link(__MODULE__, :ok, name: :facebook_accounts_producer)
  end

  def init(:ok) do
    send(self(), :populate_state)

    {:producer, {:queue.new, 0}}
  end

  def handle_demand(incoming_demand, {queue, pending_demand}) do
    {events, state} = dispatch_events(queue, incoming_demand + pending_demand, [])

    {:noreply, events, state}
  end

  def handle_info(:populate_state, {queue, pending_demand}) do
    # Keep in mind this is a strawman implementation.
    # A timer here should be handled with better care: cancelling an old timer before starting a new one.
    Process.send_after(self(), :populate_state, @repopulate_state_interval)

    if :queue.len(queue) < 25 do
      # go to database and fetch facebook accounts
      account_ids = fetch_account_ids()

      queue =
        Enum.reduce account_ids, queue, fn(account_id, acc) ->
          :queue.in(account_id, acc)
        end

      {events, state} = dispatch_events(queue, pending_demand, [])
      {:noreply, events, state}
    else
      {:noreply, [], state}
    end
  end

  # this function stores a pending demand from consumer when there are no
  # events in the state yet, copy-pasted from the GenStage doc
  defp dispatch_events(queue, 0, events) do
    {Enum.reverse(events), {queue, 0}}
  end

  defp dispatch_events(queue, demand, events) do
    case :queue.out(queue) do
      {{:value, event}, queue} ->
        dispatch_events(queue, demand - 1, [event | events])
      {:empty, queue} ->
        {Enum.reverse(events), {queue, demand}}
    end
  end

  defp fetch_account_ids() do
    # Not impl
    []
  end
end