##
# = Event Framework
#
# Event Framework is a minimalistic library providing publish–subscribe pattern
#
# === Installing
#
#  gem install event-framework
#
# === Example
#
#  require 'event-framework'
#
#  class Server
#    include EF::Object
#  end
#
#  class Client
#    include EF::Object
#  end
#
#  server = Server.new
#  client = Client.new
#
#  EF::Thread.new do
#    loop do
#      sleep 1
#      server.trigger('event', 'message')
#    end
#  end
#
#  EF::Thread.new do
#    client.listen_to(server, 'event') do |server, message|
#      puts message
#    end
#  end
#
#  EF::Loop.loop
#
# === Notices
#
# * EF::Object should be included after initialize
# * Also you may admix EF::Object methods and needed instance variables by extending: `Object.new.extend(EF::Object)`
# * Callbacks will be executed in threads of subscribers (where they were defined)
# * In the example the handler will be called in the main thread, <br> but if you define the client in the thread where you bind it to the server's event, <br> then the handler will be called in the same thread
module EF
  ##
  # === provides threads with separated event loops
  class Thread < ::Thread
    ##
    # returns instances of EF::Thread
    def self.instances
      ObjectSpace.each_object(self).to_a
    end

    ##
    # creates a thread <br>
    # parameters will be passed to the block
    def initialize(*args, &block)
      @queue = Queue.new

      super do
        block.call *args if block_given?

        while true
          args, block = @queue.pop
          block.call *args
        end
      end
    end

    ##
    # adds a task which will be executed in the event loop <br>
    # parameters will be passed to the block
    def add(*args, &block)
      raise 'block not given' unless block_given?
      @queue << [args, block]
    end
  end

  ##
  # === provides blocking event loop
  module Loop
    @@thread = nil

    ##
    # starts the loop
    def self.loop
      @@thread = Thread.new
      @@thread.value
    end

    ##
    # returns corresponding EF::Thread object <br>
    # which you can use to add new tasks
    def self.thread
      @@thread
    end
  end

  ##
  # === provides methods for publish–subscribe pattern
  module Object
    ##
    # patches initialize to admix needed variables
    def self.included(base)
      base.class_exec do
        alias alias_initialize initialize

        ##
        # defines needed variables and calls original initialize
        def initialize(*args, &block)
          alias_initialize *args, &block

          @mutex = Mutex.new

          @thread = Thread.current

          @observers = []
          @observables = []
        end
      end
    end

    ##
    # allows you to extend any object
    #  obj = Object.new
    #  obj.extend EF::Object
    def self.extended(base)
      base.instance_variable_set :@mutex, Mutex.new
      base.instance_variable_set :@thread, Thread.current
      base.instance_variable_set :@observers, []
      base.instance_variable_set :@observables, []
    end

    ##
    # returns the thread where the object was defined
    def thread
      @thread
    end

    ##
    # calls handlers for observers for the event <br>
    # parameters and the caller will be passed to the handlers <br>
    # notice: usually in threads of sibscribers
    def trigger(event, *args)
      raise 'event is not string' unless event.is_a? String

      @mutex.synchronize do
        @observers.each do |o, e, b|
          if e == event
            if Thread.instances.include? o.thread
              o.thread.add self, *args, &b
            elsif Loop.thread
              Loop.thread.add self, *args, &b
            else
              b.call self, *args
            end
          end
        end
      end
    end

    ##
    # registrate a handler for the event
    def listen_to(observable, event, &block)
      raise 'observable is not EF::Object' unless observable.is_a? Object
      raise 'event is not string' unless event.is_a? String
      raise 'block not given' unless block_given?

      @mutex.synchronize do
        @observables << [observable, event, block]

        if self == observable
          @observers << [self, event, block]
        else
          observable.registrate(self, event, block)
        end
      end
    end

    ##
    # listen to self
    def on(event, &block)
      raise 'event is not string' unless event.is_a? String
      raise 'block not given' unless block_given?

      listen_to self, event, &block
    end

    ##
    # unregistrate all matching handlers
    def stop_listening(observable=nil, event=nil, block=nil)
      @mutex.synchronize do
        observables = []

        @observables.each do |o, e, b|
          if (!observable || o == observable) && (!event || e == event) && (!block || b == block)
            if self == o
              @observers.reject! do |o, e, b|
                o == self && e == event && b == block
              end
            else
              o.unregistrate(self, e, b)
            end
          else
            observables << [o, e, b]
          end
        end

        @observables = observables
      end
    end

    ##
    # stop listening to self
    def off(event=nil, block=nil)
      stop_listening self, event, block
    end

    ##
    # by default handlers will be executed in the thread where the receiver was defined <br>
    # the method changes it so that handlers will be executed in the passed thread
    def move_to(thread)
      @mutex.synchronize do
        @thread = thread
      end
    end

    protected

    ##
    # adds observer to the list of observers
    def registrate(observer, event, block)
      @mutex.synchronize do
        @observers << [observer, event, block]
      end
    end

    ##
    # removes observer from the list of observers
    def unregistrate(observer, event, block)
      @mutex.synchronize do
        @observers.reject! do |o, e, b|
          o == observer && e == event && b == block
        end
      end
    end
  end
end

