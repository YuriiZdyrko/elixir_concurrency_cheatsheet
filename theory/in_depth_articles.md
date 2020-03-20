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

#### Videos
https://www.youtube.com/watch?v=M78r_PDlw2c
https://www.youtube.com/watch?v=XPlXNUXmcgE

#### Repos

Two SQS adapters:
https://github.com/conduitframework/conduit_sqs/blob/master/lib/conduit_sqs/poller.ex
https://github.com/dashbitco/broadway_sqs/blob/master/lib/broadway_sqs/producer.ex

#### Tutorials
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

Very good showcasing of fault-tolerance.
Example of 0..N producers to 1 Consumer.
`going_deep_with_concurrency/practice/lib/dynamic_producer` (iex - ready)
https://norbertka.me/posts/dynamic_genstage_producers/

Basic push-based (as opposite to demand-based) Producer
https://blog.jola.dev/push-based-genstage

Example of using Rate Limiting for doing search suggestions
https://www.programmableweb.com/news/how-to-use-genstage-and-websockets-to-optimize-consumption-rate-limited-apis/how-to/2018/05/20

Bare-bones buffer-limiting Producer +
Consumer that does all-the-work.
https://blog.discordapp.com/how-discord-handles-push-request-bursts-of-over-a-million-per-minute-with-elixirs-genstage-8f899f0221b4#.i3c7192m9

Interesting to see my chicken used for video-progress
Example of removing expired buffered events. Usage of metrics for monitoring.
https://blog.emerleite.com/using-elixir-genstage-to-track-video-watch-progress-9b114786c604

### Flow

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