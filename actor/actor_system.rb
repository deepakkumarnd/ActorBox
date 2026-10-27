require_relative 'supervisor'
require_relative 'address'
require 'socket'
require 'securerandom'
module Actor
  Data.define
  # ActorSystem is a special supervisor actor
  class ActorSystem
    def initialize(name: nil)
      # a mapping of actor address to actor/supervisor
      @registry = {}
      @hostname = get_hostname
      @system_id = actor_system_id
    end

    private def get_hostname
      Socket.gethostname
    end

    private def actor_system_id
      SecureRandom.hex(4).to_s
    end

    def send_message(address, message)
      SystemActor.lookup_actor(address)&.send_message(message)
    end

    # create an actor within actor system
    def actor(name: nil, &block)
      actor = Actor.new(name:, &block)
      SystemActor.register_actor(actor)
      actor.start
      actor.address
    end

    # create a supervisor within actor system
    def supervisor(name: nil, concurrency: 1, &block)
      supervisor = Supervisor.new(name:, concurrency:)
      SystemActor.register_actor(supervisor)
      supervisor.start
      supervisor.address
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
        address = ActorAddress.build(actor.object_id, @system_id, @hostname)
        actor.set_address!(address)
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