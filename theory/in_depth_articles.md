### Erlang Scheduler
https://hamidreza-s.github.io/erlang/scheduling/real-time/preemptive/migration/2016/02/09/erlang-scheduler-details.html

https://medium.com/flatiron-labs/elixir-and-the-beam-how-concurrency-really-works-3cc151cddd61

### Process dictionary
https://ferd.ca/on-the-use-of-the-process-dictionary-in-erlang.html

### handle_continue
https://medium.com/@tylerpachal/introduction-to-handle-continue-in-elixir-and-when-to-use-it-53ba5519cc17


### Registry

https://medium.com/@StevenLeiva1/elixir-process-registries-a27f813d94e3

### GenStage

Great production-style example. 
Probably most sophisticated around. Big ideas:
- showcased deeply nested GenStage hierarchy
- rate-limiting example using Facebook API quota
- very in-depth termination explanation
`going_deep_with_concurrency/practice/lib/gen_stage_hierarchy`
http://big-elephants.com/2019-01/facebook-genstage/

Easy read.
An example of using DynamicSupervisor to start multiple GenStage Consumers.
https://medium.com/@andreichernykh/elixir-a-few-things-about-genstage-id-wish-to-knew-some-time-ago-b826ca7d48ba

Article about dynamically modifying pipeline.
It's possible, by reliance on GenServer.cancel
https://stackoverflow.com/questions/52968929/runtime-dynamic-compute-graph-using-elixir-genstages

Not enough depth. More Blockchain than elixir.
https://blog.appsignal.com/2018/11/13/elixir-alchemy-understanding-elixirs-genstages-querying-the-blockchain.html

Very good showcasing of fault-tolerance.
Example of 0..N producers to 1 Consumer.
`going_deep_with_concurrency/practice/lib/dynamic_producer` (iex - ready)
https://norbertka.me/posts/dynamic_genstage_producers/


https://blog.jola.dev/push-based-genstage


### Flow

Useful for CPU or IO bound work
https://www.slideshare.net/Elixir-Meetup/genstage-and-flow-jose-valim


### Broadway

https://dockyard.com/blog/2019/10/16/batching-for-operations-with-elixir-and-broadway

https://blog.appsignal.com/2019/12/12/how-to-use-broadway-in-your-elixir-application.html

https://samuelmullen.com/articles/understanding-elixirs-broadway/
https://akoutmos.com/post/broadway-rabbitmq-and-the-rise-of-elixir-two/
https://www.youtube.com/watch?v=xWItOcqxCE0


Projects:
1. List locally tweeted emoji
https://github.com/parroty/extwitter
# OAUTH, Streams, using HTTP streaming Twitter api, GenStage:
https://github.com/parroty/extwitter/blob/master/lib/extwitter/api/streaming.ex

usage example:
https://levelup.gitconnected.com/building-a-twitter-emoji-map-with-elixirs-genstage-phoenix-channels-and-angular-134319061b8a



### Off topic

####  System design 
https://www.youtube.com/watch?v=OR2Gc6_Le2U