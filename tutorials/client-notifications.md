---
layout: default
title: Client Notifications
---

# Client Notifications

In [the previous tutorial]({{ site.baseurl }}/tutorials/scaling.html) we learned how to scale our workers. Now we will more to the different use case.
 Imagine that your service is publishing messages. Some of them are periodical (real-time status updates), some are sent as a reaction on particular events.
 Such case is very common for queue systems. You can read about it in the [introduction to RabbitMQ Concepts](https://www.rabbitmq.com/tutorials/amqp-concepts.html).
  
Let's focus on the following scenario: 

* Many application are producing log files.
* The service is collection information about logs and performs analyzes.
* Important log entries (ex. fatals and errors) are published to the components that react on them (ex. Email or SMS notifications)
* The status information (number of analyzed entries) is published on the public channel periodically (ex. every 10s)

## Log Analyzer

The log analyzer service waiting for log files to be processed is nothing new for us. 
 We will start with the controller implementation that reacts on the single message with the path to the log file.
 
The message definition is trivial:

{% highlight ruby %}
module LogAnalyzer
  class NewLog < Tochtli::Message
    route_to 'log.analyzer.new'

    attribute :path, String
  end
end
{% endhighlight %}

The initial controller code will look like this:

{% highlight ruby %}
module LogAnalyzer
  class LogController < Tochtli::BaseController
    bind 'log.analyzer.*'

    on NewLog, :create

    def create
      parser = LogParser.new(message.path)
      parser.each do |event|
        severity = event[:severity]
        ...
      end
    end
  end
end
{% endhighlight %}

Think about `LogParser` as a simple tool that enumerates each log entry as a hash with keys: `:severity`, `:timestamp` and `:message`.
 You can find it's implementation in the file [server.rb](https://github.com/PuzzleFlow/tochtli/blob/master/examples/02-log-analyzer/server.rb).
 That was simple. The next requirement states that important entries are published to the other components.
 We will achieve it with the revers communication from server to client. 
 This time server would act as a publisher and client used by the component listening to events as a subscriber.
 The simplest way to publish a message in Tochtli is to implement `Tochtli::BaseClient` child class.
 Yes, it's true. The server code is going to have client class implementation.
  
The significant entry would be published with the message:

{% highlight ruby %}
module LogAnalyzer
  class EventOccurred < Tochtli::Message
    route_to { "log.events.#{severity}" }

    attribute :severity, String
    attribute :timestamp, Time
    attribute :message, String
  end
end
{% endhighlight %}

The message attributes (`:severity`, `:timestamp` and `:message`) are obvious but what about the routing key?
 This time we we would use different topics for different event severities to allow components to listen only for selected events.
 `Tochtli::Message` allows to define routing key by passing block to the `route_to` directive.
  
OK, the message is ready. Now the client class:

{% highlight ruby %}
module LogAnalyzer
  class EventNotifier < Tochtli::BaseClient
		SIGNIFICANT_SEVERITIES = [:fatal, :error, :warn]

		def self.significant?(severity)
			SIGNIFICANT_SEVERITIES.include?(severity)
		end

    def notify(event)
      publish EventOccurred.new(event)
    end
  end
end
{% endhighlight %}

The core `LogAnalyzer::EventNotifier` method is `notify` that accepts event parameters and publishes `EventOccurred` message.
 Additionally, the client class determines if the event severity is `significant?`.
 Let's update the server code.
 
{% highlight ruby %}
module LogAnalyzer
  class LogController < Tochtli::BaseController
    bind 'log.analyzer.*'
 
    on NewLog, :create
 
    def create
      parser = LogParser.new(message.path)
      notifier = EventNotifier.new(self.rabbit_connection)
      parser.each do |event|
        severity = event[:severity]
        notifier.notify event if EventNotifier.significant?(severity)
      end
    end
  end
end

# Well known code that starts the server
Tochtli::ControllerManager.setup
Tochtli::ControllerManager.start

trap('SIGINT') { exit }
at_exit { Tochtli::ControllerManager.stop }

puts 'Press Ctrl-C to stop worker...'
sleep 
{% endhighlight %}
 
`EventNotifier` is initialized on every processed log file (the client class is lightweight) with the `Tochtli::RabbitConnection` instance.
 The connection instance can be accessed with the `Tochtli::BaseController#rabbit_connection` method. The client usage is known.

## Client

Before the first live test we have to implement the client that would be used by log producers.  

{% highlight ruby %}
module LogAnalyzer
  class Client < Tochtli::BaseClient
    def send_new_log(path)
      publish NewLog.new(path: path)
    end
  end
end

client = LogAnalyzer::Client.new
client.send_new_log ARGV[0]
{% endhighlight %}
  
It was simple. Isn't it?

## The First Test

At first let's start the server with the command: `bundle exec ruby server.rb` and client: `bundle exec ruby client.rb sample.log` for
the log file `sample.log`:
 
```
# Logfile created on 2015-08-10 10:06:45 +0200 by logger.rb/47272
D, [2015-08-10T10:07:02.366427 #4624] DEBUG -- : Sample debug
D, [2015-08-10T10:07:02.366514 #4624] DEBUG -- : Sample debug
I, [2015-08-10T10:07:02.366542 #4624]  INFO -- : Sample info
D, [2015-08-10T10:07:02.366565 #4624] DEBUG -- : Sample debug
W, [2015-08-10T10:07:02.366615 #4624]  WARN -- : Sample warn
I, [2015-08-10T10:07:02.366638 #4624]  INFO -- : Sample info
D, [2015-08-10T10:07:02.366659 #4624] DEBUG -- : Sample debug
D, [2015-08-10T10:07:02.366679 #4624] DEBUG -- : Sample debug
I, [2015-08-10T10:07:02.366699 #4624]  INFO -- : Sample info
I, [2015-08-10T10:07:02.366720 #4624]  INFO -- : Sample info
E, [2015-08-10T10:07:02.366741 #4624] ERROR -- : Sample error
D, [2015-08-10T10:07:02.366761 #4624] DEBUG -- : Sample debug
D, [2015-08-10T10:07:02.366782 #4624] DEBUG -- : Sample debug
```

I assume that you set `Tochtli.logger` to the `tochtli.log` file for both client and server. That we can review the log output:

```
I, [2015-08-11T15:44:03.867756 #57253]  INFO -- SERVER: Starting LogAnalyzer::LogController...
D, [2015-08-11T15:44:06.938811 #57255] DEBUG -- CLIENT: [2015-08-11 15:44:06 +0200 AMQP] Publishing message 2b3d5a86-c8b0-4051-8a41-076d9faf260a to log.analyzer.new
D, [2015-08-11T15:44:06.945843 #57253] DEBUG -- SERVER: 

AMQP Message LogAnalyzer::NewLog at 2015-08-11 15:44:06 +0200
D, [2015-08-11T15:44:06.945919 #57253] DEBUG -- SERVER: Processing by LogAnalyzer::LogController#create [Thread: 70282728082940]
D, [2015-08-11T15:44:06.945993 #57253] DEBUG -- SERVER: 	Message: {:path=>"sample.log"}.
D, [2015-08-11T15:44:06.946041 #57253] DEBUG -- SERVER: 	Properties: {:content_type=>"application/json", :delivery_mode=>2, :priority=>0, :reply_to=>"amq.gen-InLd6PjsrZ_Du4cC0neKYQ", :message_id=>"2b3d5a86-c8b0-4051-8a41-076d9faf260a", :timestamp=>2015-08-11 15:44:06 +0200, :type=>"log_analyzer::new_log"}.
D, [2015-08-11T15:44:06.946065 #57253] DEBUG -- SERVER: 	Delivery info: exchange: puzzleflow.services, routing_key: log.analyzer.new.
D, [2015-08-11T15:44:06.947676 #57253] DEBUG -- SERVER: [2015-08-11 15:44:06 +0200 AMQP] Publishing message 93eb45e9-6c4d-4e50-8972-8714600e401e to log.events.warn
D, [2015-08-11T15:44:06.955029 #57253] DEBUG -- SERVER: [2015-08-11 15:44:06 +0200 AMQP] Publishing message 13309bc2-f2a3-4cc7-93f9-df5e0fc4d20b to log.events.error
E, [2015-08-11T15:44:06.955795 #57253] ERROR -- SERVER: [Tochtli::ReplyQueue] Unexpected message delivery '93eb45e9-6c4d-4e50-8972-8714600e401e':
	#<Tochtli::MessageDropped: Message 93eb45e9-6c4d-4e50-8972-8714600e401e dropped: NO_ROUTE [312]>)
E, [2015-08-11T15:44:06.956176 #57253] ERROR -- SERVER: [Tochtli::ReplyQueue] Unexpected message delivery '13309bc2-f2a3-4cc7-93f9-df5e0fc4d20b':
	#<Tochtli::MessageDropped: Message 13309bc2-f2a3-4cc7-93f9-df5e0fc4d20b dropped: NO_ROUTE [312]>)
D, [2015-08-11T15:44:06.956364 #57253] DEBUG -- SERVER: Message 2b3d5a86-c8b0-4051-8a41-076d9faf260a processed in 10.5ms.

```

The single message was published by the client on topic `log.analyzer.new` with the path to `sample.log`. 
 The service controller `LogAnalyzer::LogController` processed it with `create` action.
 During log analyzes 2 messages were published on topics `log.events.warn` and `log.events.error`.
 That's correct. Our `sample.log` contained only 2 significant entries (warn and error).
 Irritating in the `tochtli.log` are entries about dropped messages.
 Both event messages were dropped because there was no queue for them to route to. 
 We haven't implemented listeners yet, so nobody is waiting for notifications.
 Tochtli publishes all messages with `mandatory` flag enabled by default.
 To get rid of the redundant log errors we have to change the flag in the `LogAnalyzer::EventNotifier#notify` method:
 
{% highlight ruby %}
module LogAnalyzer
    def notify(event)
      publish EventOccurred.new(event), mandatory: false
    end
  end
end
{% endhighlight %}

## Events Listener

We are ready to introduce the events listener to the client. How can the client listen to the log events? 
 It needs to subscribe to the queue where events are published. In Tochtli the only way to do so is to create a controller.
 Exactly, our client would have it's own controller (our service already has a client class for publishing messages).
 
{% highlight ruby %}
module LogAnalyzer
  class EventsController < Tochtli::BaseController
    on EventOccurred, :handle, routing_key: 'log.events.*'
  
    def handle
      handler.call(message.severity, message.timestamp, message.message)
    end
  
    protected
  
    def handler
      raise "Internal Error: handler not set for EventsController" unless env.has_key?(:handler)
      env[:handler]
    end
  end
end
{% endhighlight %}

The `LogAnalyzer::EventsController` accepts only `EventOccurred` message and processes it with method `handle`.
 The message has custom routing dependent on severity, therefore we need to specify routing key in `on` directive.
 The routing key defined with `on` is used by Tochtli dispatcher to find the proper message class and controller method.
 As you can see the '*' and '#' characters are accepted in the routing key.
 
In the method `handle` the `handler` is used. This is the first time we directly use controller environment (`env`).
 Usually environment variables are referred indirectly. For ex. `env[:message]` is referred by `message` accessor.
 This time the custom variable `:handler` is used. Where it come from? We will see in the moment. 
 First we need to see how the controller would be started in the client.
  
Tochtli layered structure does not allow the application to operate on controller layer. 
 The client class should provide the required functionality. Let's add next client method.
 
{% highlight ruby %}
module LogAnalyzer
  class Client < Tochtli::BaseClient
    def react_on_events(client_id, severities, handler=nil, &block)
	    handler = block unless handler
      severities = Array(severities)
	    routing_keys = severities.map {|severity| "log.events.#{severity}" }
      Tochtli::ControllerManager.start EventsController,
                                       queue_name: "log_analyzer/events/#{client_id}", # custom queue name
                                       routing_keys: routing_keys, # make custom binding (only selected severities)
                                       env: { handler: handler }
    end
  end
end
{% endhighlight %}

The log analyzer service client exposes the new API method `react_on_events` that allows to bind the handler (Proc or block)
 with events with given severities. To achieve that the `EventsController` is started and bound with the new RabbitMQ queue.
 We cannot use single queue for all clients. Each client should have it's own queue to allow for event messages broadcasting.
 The `client_id` argument is used to create a queue name. The auto generated name won't be a solution because we want to have
 a persistent queue that will collect events even when application component is turned off.
  
The selection of events is done with routing keys calculated from event severities. 
 Normally, the controller queue binding is set for a controller with `bind` directive.
 Tochtli controller manager allows to setup custom binding during start with `:routing_keys` option.

The last option passed to the controller is `:env`. That's the answer to the previous question 
 about source of custom controller environment variables.
  
The last step for now is to rewrite the client runner code. We already have 2 API methods: `send_new_log` and `react_on_events`.

{% highlight ruby %}
client = LogAnalyzer::Client.new
command = ARGV[0]

def hold
	puts 'Press Ctrl-C to stop...'
	sleep
end


case command
	when 's'
		client.send_new_log ARGV[1]
	when 'c'
		client.react_on_events ARGV[1], [:fatal, :error], lambda {|severity, timestamp, message|
			puts "[#{timestamp}] Got #{severity}: #{message}"
		}
		puts 'Press Ctrl-C to stop...'
    sleep
	else
		puts "Unknown command: #{command.inspect}"
		puts
		puts "Usage: bundle exec ruby client [command] [params]"
		puts
		puts "Commands:"
		puts "  s [path]      - send log from file to server"
		puts "  c [client ID] - catch fatal and error events"
end
{% endhighlight %}

To start the event listener run the command `bundle exec ruby client.rb c client-001`. 
 Then with server is started publish new logs with command `bundle exec ruby client.rb s sample.log`.
 You should see the output like:

```
[2015-08-10 10:07:02 +0200] Got error: Sample error
[2015-08-10 10:07:02 +0200] Got fatal: Sample fatal
[2015-08-10 10:07:02 +0200] Got error: Sample error
[2015-08-10 10:07:02 +0200] Got error: Sample error
[2015-08-10 10:07:02 +0200] Got error: Sample error
[2015-08-10 10:07:02 +0200] Got fatal: Sample fatal
...
```

## System Monitor

The last uncovered requirement is periodical (every 10s) publication of status information on public channel.
 This is very common case for monitoring systems. As always at first we will introduce the message definition.
 
{% highlight ruby %}
module LogAnalyzer
  class CurrentStatus < Tochtli::Message
    route_to 'log.status'

    attribute :fatal, Integer, default: 0
    attribute :error, Integer, default: 0
    attribute :warn, Integer, default: 0
    attribute :info, Integer, default: 0
    attribute :debug, Integer, default: 0
    attribute :timestamp, Time
  end
end
{% endhighlight %}

It consists of attributes containing the number of messages with a related severity (fatal, error, ...) and the timestamp.
 To be able to publish this message in server code we would extend the existing server's client class.
  
{% highlight ruby %}
module LogAnalyzer
  class EventNotifier < Tochtli::BaseClient
    def update_status(status)
      publish CurrentStatus.new(status), mandatory: false
    end
  end
end
{% endhighlight %}

The `update_status` method published non mandatory message (as previously) because the situation when no listener is active is normal.

The next step is implementation of the core status monitor that gathers statistics and publish status information periodically.

{% highlight ruby %}
module LogAnalyzer
  class StatusMonitor
    include MonitorMixin

    def initialize(rabbit_connection)
      super()
      @notifier = EventNotifier.new(rabbit_connection)
      @status = Hash.new(0)
    end

    def start
      Thread.new(&method(:monitor))
    end

    def note(severity)
      synchronize do
        @status[severity] += 1
      end
    end

    protected

    def reset_status
      synchronize do
        status = @status
        @status = Hash.new(0)
        status
      end
    end

    def monitor
      loop do
        current_status = reset_status
        current_status[:timestamp] = Time.now
		    @notifier.update_status current_status
        sleep 10
      end
    end
  end
end
{% endhighlight %}

In the above code there are 2 interesting methods. The first `start` run the new monitoring thread. 
 The second `note` updates the current monitor statistics. Synchronization is added for thread safety.
 Internally the `EventNotifier` client class, initialized with the rabbit connection, is used to publish periodical messages.
 
Finally, we have to find the nice place to start the monitor and glue it with the server's log analyzer.
 To do so we would use the `Tochtli::BaseController` hooks. Each controller class has access to the following hooks:
 
1. `before_setup` - run at very beginning before the controller connection is setup
2. `after_setup` - run after initial setup
3. `before_start` - run right before the controller queue is created and bound
4. `after_start` - run after queue preparation
5. `before_restart` - run before the restart action
6. `after_restart` - run after the queue binding and handlers restart

For our case the `after_setup` hook is suitable. 
 We have an access to the rabbit connection then which is required to initialize the `EventNotifier` client object.

{% highlight ruby %}
module LogAnalyzer
  class LogController < Tochtli::BaseController
    bind 'log.analyzer.*'

    on NewLog, :create

    cattr_accessor :monitor

    after_setup do |rabbit_connection|
	    self.monitor = StatusMonitor.new(rabbit_connection)
	    self.monitor.start
    end

    def create
      parser   = LogParser.new(message.path)
      notifier = EventNotifier.new(self.rabbit_connection)
      parser.each do |event|
        severity = event[:severity]
        notifier.notify event if EventNotifier.significant?(severity)
        self.monitor.note severity
      end
      notifier.wait_for_confirms
    end
  end
end
{% endhighlight %}

Additionally, the `create` action has been updated with the single line: `self.monitor.note severity` 
 that updates status monitor statistics for every log entry. 
 
The last step required for the status monitor functionality is client API implementation that will allow to listen on status updates.
 Like with events listener we have to create a controller class that will be bound with the status queue collection status updates.

{% highlight ruby %}
module LogAnalyzer
  class MonitorController < Tochtli::BaseController
    bind 'log.status'

    self.queue_name        = '' # auto generate
    self.queue_durable     = false
    self.queue_exclusive   = true
    self.queue_auto_delete = true

    on CurrentStatus do
	    monitor.call(message.to_hash)
    end

    protected

    def monitor
	    raise "Internal Error: monitor not set for MonitorController" unless env.has_key?(:monitor)
	    env[:monitor]
    end
  end
end
{% endhighlight %}

Everything looks well known except queue parameters set in the class definition. We can read from the code that
 the controller class would have auto generated name (empty string), would not be durable but exclusive and auto deleted.
 The auto generated name allow us to create different queues for each client instances. 
 The created queue would be temporary because the nature of the status information is ephemeral.
 
Let's update the client API to allow to attach handler on status update.

{% highlight ruby %}
module LogAnalyzer
  class Client < Tochtli::BaseClient
    def monitor_status(monitor=nil, &block)
	    monitor = block unless monitor
      Tochtli::ControllerManager.start MonitorController, env: { monitor: monitor }
    end
  end
end
{% endhighlight %}

This is a definition of the third and the last client method.
 The final client runner code would look like:
 
{% highlight ruby %}
client = LogAnalyzer::Client.new
command = ARGV[0]

def hold
	puts 'Press Ctrl-C to stop...'
	sleep
end


case command
	when 's'
		client.send_new_log ARGV[1]
	when 'm'
		client.monitor_status {|status| p status }
		hold
	when 'c'
		client.react_on_events ARGV[1], [:fatal, :error], lambda {|severity, timestamp, message|
			puts "[#{timestamp}] Got #{severity}: #{message}"
		}
		hold
	else
		puts "Unknown command: #{command.inspect}"
		puts
		puts "Usage: bundle exec ruby client [command] [params]"
		puts
		puts "Commands:"
		puts "  s [path]      - send log from file to server"
		puts "  m             - start status monitor"
		puts "  c [client ID] - catch fatal and error events"
end
{% endhighlight %}

That's it. Start your server. Start the status monitor and events handler. 
 Submit new log files to the server and observe the number. At the end you should see something like:
  
```
$ ruby client.rb m
Press Ctrl-C to stop...
{:fatal=>0, :error=>0, :warn=>0, :info=>0, :debug=>0, :timestamp=>2015-08-12 15:41:16 +0200}
{:fatal=>478, :error=>1500, :warn=>2364, :info=>5930, :debug=>9728, :timestamp=>2015-08-12 15:41:26 +0200}
{:fatal=>239, :error=>750, :warn=>1182, :info=>2965, :debug=>4864, :timestamp=>2015-08-12 15:41:36 +0200}
...
```

That's all folks for this tutorial. The client notifications are working exactly as expected.
You can find the client and server code in [the second tochtli example](https://github.com/PuzzleFlow/tochtli/tree/master/examples/02-log-analyzer).