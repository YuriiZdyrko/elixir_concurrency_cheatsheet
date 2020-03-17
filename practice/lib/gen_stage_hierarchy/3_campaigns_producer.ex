
defmodule Facebook.AdsAccountsConsumerSupervisor do
    @moduledoc """
    Registration: {:via, Registry, {:facebook_ads_accounts_consumer_supervisors_registry, account_id}}

    Is started dynamically from a Facebook.AdsAccountsProducer, 
    by the use of start_link(account_id, producer_pid),

    Since sybscription is :automatic,
    immediately issues a demand (max_demand: 10) to AdsAccountsProducer
    """
  use ConsumerSupervisor

  def start_link(account_id, pid_to_subscribe) do
    name = name(account_id)
    ConsumerSupervisor.start_link(__MODULE__, {pid_to_subscribe, account_id}, name: name)
  end

  def name(account_id) do
    {:via, Registry, {:facebook_ads_accounts_consumer_supervisors_registry, account_id}}
  end

  def init({pid_to_subscribe, account_id}) do
    children = [
      worker(Facebook.CampaignsProducer, [], restart: :transient)
    ]
    opts = [strategy: :one_for_one, subscribe_to: [{pid_to_subscribe, max_demand: 10, min_demand: 1}]]
    ConsumerSupervisor.init(children, opts)
  end
end

defmodule Facebook.CampaignsProducer do
    @moduledoc """
    Initialization: by ConsumerSupervisor (Facebook.AdsAccountsConsumerSupervisor)
    Registration:  {:via, Registry, {:facebook_campaigns_producers_registry, {ads_account_id, date}}}

    Dispatching:
    - starts single CampaignsConsumerSupervisor manually, 
        CampaignsConsumerSupervisor.start_link(ads_account_id, date),
        it will subscribe_to: CampaignsProducer.name(ads_account_id, date)
        # code for this is N/A
    - fetches active campaigns for a given (ads_account_id), dispatches them

    Consuming events:
    - with an @heartbeat interval, checks if there's need to keep self() alive.
        - By using :via, get child CampaignsConsumerSupervisor's count_children value: 
          via_tuple = CampaignsConsumerSupervisor.name(ads_account_id, date)
          consumer_sup_pid = GenServer.whereis(consumer_sup_name)
          count_children = ConsumerSupervisor.count_children(consumer_sup_pid)
        - if 
            - state:meta:active = true
            - queue is empty 
            - all work is finished upstream (count_children == 0), 
          stop self() with a reason :normal

    Facebook.CampaignsProducer < demand < Facebook.CampaignsConsumerSupervisor

    # Termination
    CampaignsProducer checks its state every 5 seconds 
    and when there are no more campaigns in its state to process 
    and there are no InsightsProducers active 
    => exit with :normal state, 
    which allows AdsAccountsConsumerSupervisor to spawn 
    more CampaignsProducer for the newly consumed AdsAccounts.
    """
  use GenStage

  @heartbeat_interval Application.get_env(:settings, :facebook)[:heartbeat_interval]

  def start_link({ads_account, date}) do
    GenStage.start_link(__MODULE__, {ads_account, date}, name: name(ads_account.id, date))
  end

  def name(ads_account_id, date) do
    {:via, Registry, {:facebook_campaigns_producers_registry, {ads_account_id, date}}}
  end

  def init({ads_account, date}) do
    send(self(), {:fetch_campaigns, ads_account, date})

    Process.send_after(self(), :die_maybe, @heartbeat_interval)

    meta = %{
      active: false,
      ads_account: ads_account,
      date: date
    }

    {:producer, %{demand_state: {:queue.new, 0}, meta: meta}}
  end

  # handle_demand/3 and other callbacks are omitted

  # Important omitted callback
  # handle_info(:fetch_campaigns)
    # 1. Set meta.active = true

    # 2. Initialize Consumer
    # Facebook.CampaignsConsumerSupervisor.start_link(ads_account_id, subscribe_to = self())

    # 3. Dispatch events

  # every `@heartbeat_interval` seconds (5 by default) it checks the its state
  # the `active` key in meta is set to `true` once state is populated
  # this is done to not shutdown CampaignsProducers which haven't had a chance to fetch
  # campaigns from facebook api yet
  def handle_info(:die_maybe, %{demand_state: {queue, _}, meta: meta} = state) do
    if :queue.len(queue) == 0 and meta.active and not consumers_alive?(meta.ads_account.id, meta.date) ->
      {:stop, :normal, state}
    else
      # Keep in mind this is a strawman implementation.
      # A timer here should be handled with better care: cancelling an old timer before starting a new one.
      Process.send_after(self(), :die_maybe, @heartbeat_interval)
      {:noreply, [], state}
    end
  end

  defp consumers_alive?(ads_account_id, date) do
    consumer_sup_name = Facebook.CampaignsConsumerSupervisor.name(ads_account_id, date)

    with consumer_pid when not is_nil(consumer_pid) <- GenServer.whereis(consumer_sup_name),
         %{active: active} <- ConsumerSupervisor.count_children(consumer_pid) do
      active > 0
    else
      _ ->
        false
    end
  end