```
                                                                                                                +----------+    +----------+    +----------+
                                                                                                                |Insights  |    |CostData  |    |CostData  |
                                                                                                          +---> |Producer  <----+Producer  <----+Consumer  |
                                                                                                          |     |          |    |Consumer  |    |          |
                                                                                                          |     +----------+    +----------+    +----------+
                                                                                                          |
                                                                           +------------+     +-----------+     +----------+    +----------+    +----------+
                                                                           |Campaigns   |     |Campaigns  |     |Insights  |    |CostData  |    |CostData  |
                                                                     +---> |Producer    <-----+Consumer   +-->  |Producer  <----+Producer  <----+Consumer  |
                                                                     |     |            |     |Supervisor |     |          |    |Consumer  |    |          |
                                                                     |     +------------+     +-----------+     +----------+    +----------+    +----------+
                                                                     |                                    |
                                      +------------+     +-----------+     +------------+                 |     +----------+    +----------+    +----------+
                                      |AdsAccounts |     |AdsAccounts|     |Campaigns   |                 |     |Insights  |    |CostData  |    |CostData  |
                                +---> |Producer    <-----+Consumer   +---> |Producer    |                 +---> |Producer  <----+Producer  <----+Consumer  |
                                |     |            |     |Supervisor |     |            |                       |          |    |Consumer  |    |          |
                                |     +------------+     +-----------+     +------------+                       +----------+    +----------+    +----------+
                                |                                    |
+-----------+       +-----------+     +------------+                 |     +------------+
| Accounts  |       |Accounts   |     |AdsAccounts |                 |     |Campaigns   |
| Producer  | <-----+Consumer   +---> |Producer    |                 +---> |Producer    |
|           |       |Supervisor |     |            |                       |            |
+-----------+       +-----------+     +------------+                       +------------+
                                |
                                |     +------------+
                                |     |AdsAccounts |
                                +---> |Producer    |
                                      |            |
                                      +------------+
```


```elixir
AccountsProducer # gets and buffers account_ids from database
# started automatically when the app is started
AccountsConsumerSupervisor
# started automatically when the app is started
# children:
-> [AdsAccountsProducer] # (account_id) -> ads_account_ids
    
      -> AdsAccountsConsumerSupervisor 
      # started using start_link(account_id, subscribe_to = self())
      # when AdsAccountsProducer is initialized
      # children:
      -> [CampaignsProducer] # (ads_account_id) -> campaign_ids
        
            -> CampaignsConsumerSupervisor 
            # started using start_link(ads_account_id, subscribe_to = self())
            # when CampaignsProducer is initialized
            # children:
            -> [InsightsProducer] # (campaign_id) -> cost_data
            
                  -> CostDataProducerConsumer
                  # started using start_link(..args, subscribe_to = self()
                  # when InsightsProducer is initialized
                
                        -> CostDataConsumer
                              # started using start_link(..args, subscribe_to = self()
                              # when CostDataProducerConsumer is initialized
```

CostDataProducerConsumer is used as a RateLimiter.

```elixir
acc_ids -> acc_id   ->  ads_acc_id    -> campaign -> cost_data -> store in db :)
                                      -> campaign -> cost_data -> store in db :)
                                      -> campaign -> ...
                                      ...
                    ->  ads_acc_id -> ...
                    ->  ads_acc_id -> ...

        -> acc_id   ->  ads_acc_id    -> campaign -> cost_data -> store in db :)
                                      -> campaign -> cost_data -> store in db :)
                                      -> campaign -> ...
                                      ...
                    ->  ads_acc_id -> ...
                    ->  ads_acc_id -> ...
```