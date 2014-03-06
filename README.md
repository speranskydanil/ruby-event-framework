# Ruby Event Framework

Event Framework is a minimalistic library providing publish–subscribe pattern.

### Installing

    gem install event-framework

### Example

    require 'event-framework'

    class Server
      include EF::Object
    end

    class Client
      include EF::Object
    end

    server = Server.new
    client = Client.new

    EF::Thread.new do
      loop do
        sleep 1
        server.trigger('event', 'message')
      end
    end

    EF::Thread.new do
      client.listen_to(server, 'event') do |server, message|
        puts message
      end
    end

    EF::Loop.loop

### Notices

* EF::Object should be included after initialize
* Also you may admix EF::Object methods and needed instance variables  
by extending: `Object.new.extend(EF::Object)`
* Callbacks will be executed in threads of subscribers (where they were defined)
* In the example the handler will be called in the main thread,  
but if you define the client in the thread where you bind it to the server's event,  
then the handler will be called in the same thread
* You can create docs by `rdoc lib`

### Docs

**EF::Thread**  
*provides threads with separated event loops*

**EF::Thread.new(*args, &block)**  
*creates a thread  
parameters will be passed to the block*

**EF::Thread#add(*args, &block)**  
*adds a task which will be executed in the event loop  
parameters will be passed to the block*

**EF::Loop**  
*provides blocking event loop*

**EF::Loop.loop**  
*starts the loop*

**EF::Loop.thread**  
*returns corresponding EF::Thread object  
which you can use to add new tasks*

**EF::Object**  
*provides methods for publish–subscribe pattern*

**EF::Object#thread**  
*returns the thread where the object was defined*

**EF::Object#trigger(event, *args)**  
*calls handlers for observers for the event  
parameters and the caller will be passed to the handlers  
notice: usually in threads of sibscribers*

**EF::Object#listen_to(observable, event, &block)**  
*registrate a handler for the event*

**EF::Object#on(event, &block)**  
*listen to self*

**EF::Object#stop_listening(observable=nil, event=nil, block=nil)**  
*unregistrate all matching handlers*

**EF::Object#off(event=nil, block=nil)**  
*stop listening to self*

**EF::Object#move_to(thread)**  
*by default handlers will be executed in the thread where the receiver was defined  
the method changes it so that handlers will be executed in the passed thread*

**Author (Speransky Danil):**
[Personal Page](http://dsperansky.info) |
[LinkedIn](http://ru.linkedin.com/in/speranskydanil/en) |
[GitHub](https://github.com/speranskydanil?tab=repositories) |
[StackOverflow](http://stackoverflow.com/users/1550807/speransky-danil)

