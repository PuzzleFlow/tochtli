---
layout: default
title: Scaling
---

# Scaling

In [the previous tutorial]({{ site.baseurl }}/tutorials/getting-started.html) we learned how to create basic service for making screenshots of web pages with Tochtli. However, how will it behave when many clients want to work with it at the same time? Let's modify our client code to find out.

{% highlight ruby %}
threads = []
20.times do |i|
	threads << Thread.new do
		ScreenerClient.new.create_screen(ARGV[0], ARGV[1].gsub('N', i.to_s))
	end
end
threads.each(&:join)
{% endhighlight %}

There is a small change here, allowing to get appropriate number of output file – one per each client. I also modified server to print into STDOUT when processing of a request starts and ends, to see what happens. Now when we run ` bundle exec ruby client.rb http://google.com googleN.png`. Whoops, no concurrency here! The server processes one message at the time and after finishing it, moves to another. Completing 20 requests in our example takes quite some time and it is possible that some requests will fail due to timeouts. Not too scalable, but we can do two things to improve it.

## Horizontal scaling

First thing that comes to mind is to fire up more servers. This will, actually, work out of the box here. When you start another instance of server and start the client, you will see that both servers are processing one request at time and whole process is twice as short.

**NOTE**: If you start one server, run a client, and only then start another server, the requests will still be processed only by the first one. This is due to nature of underlying RabbitMQ – the messages (requests) have already been delivered and now are queued for processing. From perspective of newly started server, they never existed, even though they are not finished yet.

## Work pools

The solution mentioned above is simple and _simple_ is good, but frequently not good enough. Fortunately, Tochtli has a built-in mechanism for more concurrent processing. I'm talking about work pools here. Work pools are set per controller **class** and default size of them is 1. You can easily change by setting appropriate class attribute (it's `ActiveSupport`'s `class_attribute`, so it works nicely with inheritance, you don't need to worry).

{% highlight ruby %}
class ScreenerController < Tochtli::BaseController
	subscribe 'screener.*'
	self.work_pool_size = 5
[...]
{% endhighlight %}

Now you will probably see something like this as your server's STDOUT (if you adjusted it like I did):

```
Starting processing google11.png
Starting processing google7.png
Starting processing google19.png
Starting processing google3.png
Starting processing google4.png
Finished processing google11.png
Finished processing google7.png
Finished processing google19.png
Starting processing google17.png
Finished processing google3.png
Finished processing google4.png
Starting processing google6.png
Finished processing google17.png
Finished processing google6.png
Starting processing google8.png
Starting processing google12.png
Starting processing google13.png
Finished processing google8.png
Finished processing google12.png
Finished processing google13.png
...
```

So, as we see, we now have true concurrent processing within one node!
Next lesson will show [how to listen on notifications in client]({{ site.baseurl }}/tutorials/client-notifications.html).
