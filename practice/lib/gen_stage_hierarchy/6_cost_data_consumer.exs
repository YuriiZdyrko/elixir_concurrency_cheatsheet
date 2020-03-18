defmodule Facebook.CostDataConsumer do
  @moduledoc """
  Receive events, store in database.

  This is the consumer, so no-one subscribed to it.
  handle_events in Consumers always returns {:noreply, [], state}

  insights_queue_len = GenServer.call(pid, :get_queue_len)
  if there are no events left in CostDataProducer, no need to demand more events
  so we the {:stop, :normal, state} CostDataConsumer

  # Termination
  Since CostDataConsumer, CostDataProducerConsumer and InsightsProducer are 
  linked using start_link/3, termination of CostDataConsumer 
  would terminate InsightsProducer and CostDataProducerConsumer 
  with the same status. 
  Once InsighsProducer goes down with :normal state, 
  CampaignsConsumerSupervisor can demand more campaigns 
  from CampaignsProducer and spawn more InsightsProducers for the new campaigns.
  """
  use GenStage

  @ttl_interval Application.get_env(:settings, :facebook)[:ttl_interval]

  def start_link(ads_account, campaign_id, date, subscribe_to_pid) do
    GenStage.start_link(
      __MODULE__, 
      {ads_account, campaign_id, date, subscribe_to_pid}, 
      name: name(ads_account.id, campaign_id, date)
    )
  end

  def name(ads_account_id, campaign_id, date) do
    {:via, Registry, {:facebook_cost_data_consumers_registry, {ads_account_id, campaign_id, date}}}
  end

  def init({ads_account, campaign_id, date, subscribe_to_pid}) do
    state = %{
      ads_account: ads_account,
      campaign_id: campaign_id,
      date: date
    }
    {:consumer, state, subscribe_to: [{subscribe_to_pid, subscription_opts()}]}
  end

  # simplified version of `handle_events/3` callback
  def handle_events(events, _from, state) do
    Enum.each(events, fn(event) -> store_data(event) end)

    {:noreply, [], state}
  end

  # CostDataConsumer gets this event from `CostDataProducerConsumer` and sends another one
  # to itself to terminate itself with `:normal` state.
  def handle_info(:last_event, state) do
    Process.send_after(self(), :die, @ttl_interval)

    {:noreply, [], state}
  end

  def handle_info(:die, state) do
    {:stop, :normal, state}
  end
end