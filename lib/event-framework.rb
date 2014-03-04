##
# = Event Framework
#
# Event Framework is a minimalistic library providing publish–subscribe pattern
#
# === Example
#
#  require_relative 'event-framework'
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
# * Callbacks will be executed in threads of subscribers (where they were defined)
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
        observable.registrate(self, event, block)
      end
    end

    ##
    # listen to self
    def on(event, &block)
      raise 'event is not string' unless event.is_a? String
      raise 'block not given' unless block_given?

      @mutex.synchronize do
        listen_to self, event, &block
      end
    end

    ##
    # unregistrate all matching handlers
    def stop_listening(observable=nil, event=nil, block=nil)
      @mutex.synchronize do
        observables = []

        @observables.each do |o, e, b|
          if (!observable || o == observable) && (!event || e == event) && (!block || b == block)
            o.unregistrate(self, e, b)
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
      @mutex.synchronize do
        stop_listening self, event, block
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

