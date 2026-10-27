require_relative 'supervisor'

module Actor
  # ActorSystem is a special supervisor actor
  class ActorSystem
    def initialize(name: nil)
      # a mapping of actor address to actor/supervisor
      @registry = {}
    end

    def send_message(address, message)
      $actor_system.lookup_actor(address)&.send_message(message)
    end

    # create an actor within actor system
    def actor(name: nil, &block)
      instance = Actor.new(name:, &block)
      $actor_system.register_actor(instance)
      instance.start
      instance.address
    end

    # create a supervisor within actor system
    def supervisor(name: nil, concurrency: 1, &block)
      instance = Supervisor.new(name:, concurrency:)
      $actor_system.register_actor(instance)
      instance.start
      instance.address
    end

    def send_message(address, message)
      actor = lookup_actor(address)
      
      if actor.nil?
        warn("Actor not found for address #{address}")
        return
      end
      
      actor.send_message(message)
    end

    def register_actor(actor)
      if @registry.key?(actor.address)
        log("Already registered actor")
      else
        @registry[actor.address] = actor
      end
    end

    def lookup_actor(address)
      @registry[address]
    end

    def await
      @registry.values.each(&:await)
    end

    def stop
      @registry.values.each { it.send_message(ControlMessage::STOP) }
      await
    end

    def wait
      shutdown = Queue.new
      Signal.trap('INT') { shutdown.push(:shutdown) }
      Signal.trap('TERM') { shutdown.push(:shutdown) }
      shutdown.pop
      stop
    end
  end
end