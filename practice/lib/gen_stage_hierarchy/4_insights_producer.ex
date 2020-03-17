defmodule Facebook.CampaignsConsumerSupervisor do
  use ConsumerSupervisor

  def start_link(pid_to_subscribe, ads_account, date) do
    name = name(account_id)
    ConsumerSupervisor.start_link(__MODULE__, {pid_to_subscribe, ads_account, date}, name: name)
  end

  def init({pid_to_subscribe, ads_account, date}) do
    opts = [strategy: :one_for_one, subscribe_to: [
      {pid_to_subscribe, max_demand: 10, min_demand: 1}
    ]]
    children = [
      worker(Facebook.InsightsProducer, [], restart: :transient)
    ]
    ConsumerSupervisor.init(children, opts)
  end

  def name(ads_account_id, date) do
    {:via, Registry, {:facebook_campaigns_consumer_supervisor_registry, {ads_account_id, date}}}
  end
end

defmodule InsightsProducer do
    @moduledoc """
    gets campaign’s Insights from Facebook API
    puts the data into its state and starts a consumer for itself 
    (Facebook.CostDataProducerConsumer)
    
    InsightsProducer < demand < Facebook.CostDataProducerConsumer
    """
end