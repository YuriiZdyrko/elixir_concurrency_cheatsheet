defmodule Facebook.AccountsConsumerSupervisor do
  @moduledoc """
  Started automatically during app startup,
  since subscription by default is :automatic,
  immediately issues 25 demand to AccountsProducer
  """
  use ConsumerSupervisor

  def start_link do
    ConsumerSupervisor.start_link(__MODULE__, :ok, name: :facebook_accounts_consumer_supervisor)
  end

  def init(:ok) do
    children = [
      worker(Facebook.AdsAccountsProducer, [], restart: :transient)
    ]
    opts = [strategy: :one_for_one, subscribe_to: [{:facebook_accounts_producer, max_demand: 25, min_demand: 1}]]
    ConsumerSupervisor.init(children, opts)
  end
end

defmodule Facebook.AdsAccountsProducer do

@moduledoc """
  Initialization: by ConsumerSupervisor
  Registration:  {:via, Registry, {:facebook_ads_accounts_producers_registry, account_id}}

  Dispatching:
  - after starting, immediatly fetches ads_accounts list, turns them into {ad_account, date} list
    [{account1, date1}, {account1, date2}, {account2, date1} ...]
  - dynamically starts Facebook.AdsAccountsConsumerSupervisor, using 
    Facebook.AdsAccountsConsumerSupervisor.start_link(account_id, self())

  Facebook.AdsAccountsProducer < demand < Facebook.AdsAccountConsumerSupervisor

  # Termination
  Same logic as in CampaignsProducer:
  (
    - after events had been initially received
      - check each 5 seconds, and if:
        - no events left in queue
        - no AccountsConsumerSupervisor child is running
          true? exit(:normal)
  )
"""

  use GenStage

  def start_link(account_id) do
    GenStage.start_link(__MODULE__, account_id, name: name(account_id))
  end

  def name(account_id) do
    {:via, Registry, {:facebook_ads_accounts_producers_registry, account_id}}
  end

  def init(account_id) do
    send(self(), {:fetch_ads_accounts, account_id})

    # meta is a small map with several keys, it holds some useful information
    # like when process was started or facebook account_id
    {:producer, %{demand_state: {:queue.new, 0}, meta: meta}}
  end

  def handle_demand(incoming_demand, %{demand_state: {queue, pending_demand}} = state) do
    {events, demand_state} = dispatch_events(queue, incoming_demand + pending_demand, [])
    state = Map.put(state, :demand_state, demand_state)

    {:noreply, events, state}
  end

  def handle_info({:fetch_ads_accounts, account_id}, %{demand_state: {queue, pending_demand}} = state) do
    # fetch ads_accounts per facebook account_id from database
    ads_accounts = fetch_ads_accounts(account_id)

    queue =
      Enum.reduce ads_accounts, queue, fn(ads_account, acc) ->
        # based on the timestamp when ads_account was processed,
        # determine for which date we should fetch the data from facebook
        dates_to_fetch = calculate_dates_to_fetch(ads_account)
        Enum.reduce dates_to_fetch, acc, fn(date, acc_2) ->
          :queue.in({ads_account, date}, acc_2)
        end
      end

    {events, demand_state} = dispatch_events(queue, pending_demand, [])

    state = Map.put(state, :demand_state, demand_state)

    # Start the consumer
    # Facebook.AdsAccountsConsumerSupervisor.start_link(account_id, self())

    {:noreply, events, state}
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
end