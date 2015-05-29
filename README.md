[![Build Status](https://travis-ci.org/PuzzleFlow/tochtli.svg?branch=master)](https://travis-ci.org/PuzzleFlow/tochtli)

# Tochtli

Tochtli standardizes the way of services implementation to minimize the impact of API change on application code.
  It uses RabbitMQ as a message broker with [bunny](https://github.com/ruby-amqp/bunny) client. 
 
## Idea

```
app <-> client -> request (message) -> service queue -> request (message)  -> controller <-> service
           ^                                                                      |
           |---- response (message) <-  reply queue  <- response (message) <-------
```

The communication between application and service looks like on the above picture.
  The [application](application) acts with the [client](client) which is a regular object. 
  The client methods exposes the service API. 
  The request (a [message](message)) is sent by the client to the well known [service queue](queue).
  RabbitMQ is used as a message broker and delivers the request to the [service controller](controller).
  The controller implements the actions that are performed on the request and may result in the response.
  The response message is published on the reply queue and sent back to the client which returns the expected result to the application.

### Layers
  
```
----------------------------------    ------------------------------|---------------------
 Application                     |    | Service                     | Application Layer
---------------------------------|    |-----------------------------|---------------------
 Client                          |    | Controller                  | Client Layer
--------------------------------------------------------------------|---------------------
 Messages, Cache, Configurations                                    | Common Layer
--------------------------------------------------------------------|---------------------
 RabbitMQ, HTTP, Redis, Memcache, etc.                              | Tools Layer
--------------------------------------------------------------------|---------------------
```

To fulfill the idea of resistance on the service API change the layered structure is proposed.
  Of course, like in any layered structure, the communication is allowed only with neighbour layers.
  Therefore, application is not allowed to operate on messages layer which is a private for service implementation.
  The client layer exposes the high-level service API and works on common layer where messages are defined (low-level API).
  At the bottom, there is the tools layer where RabbitMQ is an example. 

### Application

The application is the piece of code that is using the service functionality through the API exposed by the client. 

### Service

The service is a core implementation of the service functionality invoked by the service controller.

### Client

The client is a simple object that exposes the service functionality to the application with simple methods.

### Controller

The controller is a reactor that listens on the message queue and invokes the service functionality.

### Message

The message is a serializable object that holds the piece of information that is transmitted via message queue. 

### Tool

The main tool used here is a message broker (RabbitMQ). It can be also a cache server, database or web services.

# License

Released under the MIT license.