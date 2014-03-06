require 'rspec'

require './lib/event-framework'

describe 'EF' do
  describe 'Thread' do
    thread = nil

    describe '::new' do
      it 'calls given block with passed parameters' do
        params = [1, 2]

        block = proc {}

        expect(block).to receive(:call).with(*params)

        thread = EF::Thread.new(*params, &block)

        sleep 0.05
      end
    end

    describe '::instances' do
      it 'returns created threads' do
        expect(EF::Thread.instances).to eq([thread])
      end
    end

    describe '#add' do
      it 'adds a task to the queue' do
        params = [1, 2]

        block =  proc {}

        expect(block).to receive(:call).with(*params)

        thread.add(*params, &block)

        sleep 0.05
      end
    end
  end

  describe 'Loop' do
    describe '::loop' do
      it "creates a thread with it's own event loop" do
        expect(EF::Thread).to receive(:new).once

        Thread.new do
          EF::Loop.loop
        end

        sleep 0.05
      end
    end

    describe '::thread' do
      it 'returns thread for the loop' do
        instances = EF::Thread.instances

        Thread.new do
          EF::Loop.loop
        end

        sleep 0.05

        expect(EF::Thread.instances - instances).to eq([EF::Loop.thread])
      end
    end
  end

  describe 'Object' do
    it 'admixes new methods using including' do
      class C
        include EF::Object
      end

      c = C.new

      expect(c).to respond_to(:trigger)
      expect(c).to respond_to(:listen_to)
      expect(c).to respond_to(:on)
      expect(c).to respond_to(:stop_listening)
      expect(c).to respond_to(:off)
      expect(c).to respond_to(:thread)
      expect(c).to respond_to(:move_to)
    end

    it 'admixes new methods using extending' do
      object = Object.new

      object.extend EF::Object

      expect(object).to respond_to(:trigger)
      expect(object).to respond_to(:listen_to)
      expect(object).to respond_to(:on)
      expect(object).to respond_to(:stop_listening)
      expect(object).to respond_to(:off)
      expect(object).to respond_to(:thread)
      expect(object).to respond_to(:move_to)
    end

    it 'admixes new instance variables using inluding' do
      class C
        include EF::Object
      end

      c = C.new

      expect(c.instance_variable_defined? :@mutex).to be true
      expect(c.instance_variable_defined? :@thread).to be true
      expect(c.instance_variable_defined? :@observers).to be true
      expect(c.instance_variable_defined? :@observables).to be true
    end

    it 'admixes new instance variables using extending' do
      object = Object.new

      object.extend EF::Object

      expect(object.instance_variable_defined? :@mutex).to be true
      expect(object.instance_variable_defined? :@thread).to be true
      expect(object.instance_variable_defined? :@observers).to be true
      expect(object.instance_variable_defined? :@observables).to be true
    end

    describe '#thread' do
      it 'returns the thread where the object was defined (if not used move_to)' do
        object = Object.new

        object.extend EF::Object

        expect(object.thread).to equal(Thread.current)

        thread = Thread.new do
          object.extend EF::Object
        end

        sleep 0.05

        expect(object.thread).to equal(thread)
      end

      it 'returns the thread the object was moved to using move_to' do
        object = Object.new

        object.extend EF::Object

        thread = Thread.new {}

        object.move_to(thread)

        expect(object.thread).to equal(thread)
      end
    end

    describe '#listen_to' do
      it 'registers connection between two objects, makes trigger work' do
        server = Object.new
        server.extend EF::Object

        client = Object.new
        client.extend EF::Object

        thread = EF::Thread.new

        client.move_to(thread)

        d = double()
        expect(d).to receive(:call).with(thread)

        client.listen_to(server, 'event') do
          d.call(Thread.current)
        end

        server.trigger('event')

        sleep 0.05
      end
    end

    describe '#on' do
      it 'registers connection to self' do
        object = Object.new
        object.extend EF::Object

        thread = EF::Thread.new

        object.move_to(thread)

        d = double()
        expect(d).to receive(:call).with(thread)

        object.on('event') do
          d.call(Thread.current)
        end

        object.trigger('event')

        sleep 0.05
      end
    end

    describe '#stop_listening' do
      it 'unregisters connection between two objects' do
        server = Object.new
        server.extend EF::Object

        client = Object.new
        client.extend EF::Object

        thread = EF::Thread.new

        client.move_to(thread)

        d = double()
        expect(d).to_not receive(:call).with(thread)

        client.listen_to(server, 'event') do
          d.call(Thread.current)
        end

        client.stop_listening

        server.trigger('event')

        sleep 0.05
      end
    end

    describe '#off' do
      it 'unregisters connection to self' do
        object = Object.new
        object.extend EF::Object

        thread = EF::Thread.new

        object.move_to(thread)

        d = double()
        expect(d).to_not receive(:call).with(thread)

        object.listen_to(object, 'event') do
          d.call(Thread.current)
        end

        object.off

        object.trigger('event')

        sleep 0.05
      end
    end

    describe '#trigger' do
      it 'copes with difficult situations' do
        class C
          include EF::Object
        end

        thread_1 = EF::Thread.new do
          object_1 = C.new
          object_2 = C.new

          thread_2 = EF::Thread.new do
            object_3 = C.new
            object_4 = C.new

            d = double

            expect(d).to receive(:call).with(2, 1, thread_1)
            expect(d).to receive(:call).with(4, 1, thread_2)

            object_2.listen_to(object_1, 'event_1') { d.call(2, 1, Thread.current) }
            object_2.listen_to(object_1, 'event_2') { d.call(2, 2, Thread.current) }
            object_3.listen_to(object_1, 'event_1') { d.call(3, 1, Thread.current) }
            object_3.listen_to(object_1, 'event_2') { d.call(3, 2, Thread.current) }
            object_4.listen_to(object_1, 'event_1') { d.call(4, 1, Thread.current) }
            object_4.listen_to(object_1, 'event_2') { d.call(4, 2, Thread.current) }

            object_3.stop_listening(nil, 'event_1')

            object_1.trigger('event_1')
          end
        end

        sleep 0.05
      end
    end
  end
end

