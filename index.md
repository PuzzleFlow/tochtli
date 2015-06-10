---
layout: default
title: Home
---

# Tochtli

Tochtli standardizes the way of services implementation to minimize the impact of API change on application code. It uses RabbitMQ as a message broker with [bunny client](https://github.com/ruby-amqp/bunny). It has been written at PuzzleFlow and then extracted into an open source gem.

[Get started &raquo;]({{ site.baseurl }}/tutorials/getting-started.html)

## Why the funky name?

Since we are based on **Rabbit**MQ and **Bunny** gem, it seemed natural to go with some _Leporidae_-ish name for the project. At first we wanted to go with **Centzon Totochtin** (which means "four hundred rabbits") and are _divine rabbits, and the gods of drunkenness_ in Aztec and Maya mythology. But because of difficulties with remebering and pronounciating it, we decided to go with simpler **Tochtli**, which is simply a Nahuatl word for "rabbit".

## Why RabbitMQ?

It proved to be reliable and durable enough to rely on it. However, we are open to building an abstraction which would allow to plug ØMQ or Redis PubSub instead.

## How is it better than Resque or Sidekiq?

It's not better, it's different. With traditional background processing (at least that available in Ruby world) you launch a job and forget it. It may fail terribly and the system will be notified about that but there is no way to react to it at application level. You also would have to implement some hacks to get notified that the job was succesful. We wanted something different, which would give us full and reliable communication between clients and server (with acknowledgements, when necessary).

![]({{ site.baseurl}}/images/easter_centzon_totochtin_by_anadiasarts-d79dl4l.jpg)
Centzon Totochlin visualized by [AnaDiasArts](http://www.deviantart.com/art/Easter-Centzon-Totochtin-439013685).
