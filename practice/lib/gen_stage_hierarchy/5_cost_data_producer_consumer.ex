defmodule Facebook.CostDataProducerConsumer do
  @moduledoc """
  An example of rate-limiting, 
  to prevent too many requests to facebook api.
  fetch_hourly_distribution request to Facebook API is used
  to fetch quota, which is then used for rate-limiting.

  Consumes events one by one, 
  for every consumed event (an ad) 
  it sends additional HTTP request to Facebook API, 
  gets the data and passes it further to CostDataConsumer

  CostDataProducerConsumer < demand < CostDataConsumer
  """

  use GenStage

  # subscribe_to_pid is PID of InsightsProducer
  def start_link(apps, ads_account, campaign_id, date, subscribe_to_pid) do
    GenStage.start_link(__MODULE__, {apps, ads_account, campaign_id, date, subscribe_to_pid}, name: name(ads_account.id, campaign_id, date))
  end

  def name(ads_account_id, campaign_id, date) do
    {:via, Registry, {:facebook_cost_data_producers_registry, {ads_account_id, campaign_id, date}}}
  end

  def init({apps, ads_account, campaign_id, date, subscribe_to_pid}) do
    Facebook.CostDataConsumer.start_link(ads_account, campaign_id, date, self())

    # state would contain some meta info
    state = %{campaign_id: campaign_id, ads_account: ads_account, date: date}

    # note that there is no max_demand or min_demand here
    {:producer_consumer, state, subscribe_to: [subscribe_to_pid]}
  end

  # a callback is invoked when this producer_consumer is subscribed to InsightsProducer
  def handle_subscribe(:producer, _opts, from, state) do
    # once this consumer is subscribed, ask InsightsProducer for one event
    GenStage.ask(from, 1)

    state = Map.put(state, :from, from)

    {:manual, state}
  end

  # a callback is invoked when CostDataConsumer is subscribed to this ProducerConsumer
  # CostDataConsumer would consume events in automatic mode asking for max_demand events
  def handle_subscribe(:consumer, _opts, _from, state) do
    {:automatic, state}
  end

  # here is super simplified version of `handle_events/3` callback
  #
  # we always ask for only one event, that's why [event] here
  def handle_events([event], {pid, _sub_tag}, state) do
     insights_queue_len = GenServer.call(pid, :get_queue_len)

    # send a request to fb api
    {hourly_distribution, quota} = fetch_hourly_distribution(event, state)

    # apply hourly distribution to the daily data
    events = apply_hourly_distribution(event)

    if insights_queue_len == 0 do
      cost_data_consumer_pid =
        Facebook.CostDataConsumer.name(state.ads_account.id, state.campaign_id, state.date)
        |> GenServer.whereis()

      # if there are no events left in InsightsProducer, no need to demand more events
      # just tell the CostDataConsumer that these `events` are the last ones
      if cost_data_consumer_pid, do: send(cost_data_consumer_pid, :last_event)
    else
      # demand new event with a possible timeout
      demand_event_maybe(quota)
    end

    {:noreply, events, state}
  end

  # a callback to ask one more event from InsightsProducer
  # the pid of InsightsProducer is put into state in `handle_subscribe/4` callback
  def handle_info(:demand_event, state) do
    GenStage.ask(state.from, 1)
  end

  # if quota is too high, ask an event a bit later
  defp demand_event_maybe(quota) when quota > 90 do
    Process.send_after(self(), :demand_event, :timer.minutes(2))
  end

  defp demand_event_maybe(_), do: send(self(), :demand_event)
end