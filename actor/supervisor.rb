require_relative 'actor'

module Actor
  class Supervisor < Actor
    def initialize(name: 'actor', concurrency: 1, &block)
      @name = name
      @concurrency = concurrency
      @actors = concurrency.times.map { Actor.new(name:, &block) }
      @round_robin = @actors.cycle
      super(name: "#{@name}-supervisor")
    end

    def concurrency
      @concurrency
    end

    def start
      @thread = run
      @thread.name = name
    end

    def sleepmilli(milliseconds)
      sleep(milliseconds/1000.0)
    end

    private def run
      Thread.new do
        start_hooks
        # Run all actors
        start_all

        loop do
          message = get_message
          
          log("Supervise #{message}")

          if stop_message? message
            stop_all
            break
          else
            # forward message to actors in a round robin fashion
            # with exponential backoff
            attempt = 1
            done = next_actor.send_message(message)
            exponent = 0

            while done != ControlMessage::OK
              log('Waiting for free mailbox')
              sleepmilli(50 + (2**exponent))
              attempt += 1
              done = next_actor.send_message(message)
              exponent = attempt % concurrency
            end
          end
        end

        stop_hooks
      end
    end

    private def next_actor
      @round_robin.next
    end

    private def broadcast(message)
      @actors.each { it.send_message(message) }
    end

    private def await_for_all
      @actors.each(&:await)
    end

    private def start_all
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