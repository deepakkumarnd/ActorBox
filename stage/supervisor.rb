require_relative 'actor'

module Stage
  class Supervisor < Actor
    # mailbox size is for the concurrent actors not for supervisor
    def initialize(name: nil, concurrency: 1, mailbox_size: nil, system: nil, &block)
      @concurrency = concurrency
      @actors = concurrency.times.map do
        actor = Actor.new(name:, mailbox_size:, &block) 
        system.register_actor(actor) if system
        actor
      end
      @round_robin = @actors.cycle
      set_name(name)
      super()
    end

    private def set_name(name)
      @name = name.end_with?('-supervisor') ? name : "#{name}-supervisor"
    end

    def concurrency
      @concurrency
    end

    def start
      @thread = run
      @thread.name = name
    end

    def sleepmilli(milliseconds)
      log("Sleeping #{milliseconds/1000.0} seconds")
      @state = WAITING
      sleep(milliseconds/1000.0)
      @state = RUNNING
    end

    def stats
      {
        name: name,
        address: address,
        state: state,
        message_count: @mailbox.length,
        concurrency: concurrency,
        actors: @actors.map(&:stats)
      }
    end

    private def run
      Thread.new do
        start_hooks
        # Run all actors
        start_all

        loop do
          message = get_message
          log("processing #{message}")

          if stop_message? message
            log("Stop message received")
            stop_all
            break
          else
            forward_message(message)
          end
        end

        stop_hooks
      end
    end

    private def forward_message(message)
      # forward message to actors in a round robin fashion
      # with exponential backoff if actor mailboxes reject
      # message
      attempt = 0
      exponent = 0
      cycle_count = 0
      active_actor_count = @actors.filter { !it.stopped? }.length

      loop do
        actor = next_actor
        
        if actor.stopped?
          active_actor_count -= 1
          active_actor_count > 0 ? next : break
        end

        status = next_actor.send_message(message)
        break if status == ControlMessage::OK

        attempt += 1
        exponent = attempt % active_actor_count
        
        # Wait after checking with all actors once
        if exponent > cycle_count
          log("None of the actors accept the message, waiting a bit for actors to finish")
          sleepmilli(100 * (2** attempt))
          cycle_count = exponent
        end
      end
    end

    private def broadcast(message, attempts = 0)
      sleepmilli(100 * (2** attempts)) if attempts > 0

      success = @actors
        .filter { !it.stopped? }
        .map { it.send_message(message) }
        .all? { it == ControlMessage::OK }

      # recursively try till all the actors accepts the broadcast
      broadcast(message, attempts + 1) if !success
    end

    private def next_actor
      @round_robin.next
    end

    private def await_for_all
      @actors.each(&:await)
    end

    private def start_all
      log('Starting all actors')
      @actors.each(&:start)
    end

    private def cleanup_all
      @actors.each(&:cleanup)
    end

    private def stop_all
      # broadcast stop message to all actors await for all of them
      # to finish.
      broadcast(ControlMessage::STOP)
      await_for_all
      cleanup_all
    end
  end
end