require_relative 'mailbox'

module Actor
  class Actor
    READY = :ready
    RUNNING = :running
    WAITING = :waiting
    STOPPED = :stopped

    def initialize(name: 'actor', mailbox_size: nil, &block)
      @name = name
      @mailbox = MailBox.new(mailbox_size)
      @block = block
      @state = READY
    end

    def name
      @name
    end

    def send_message(message)
      if stopped?
        log("Can't send messages to stopped actor")
        return ControlMessage::REJECTED 
      end

      @mailbox.enqueue(message)
    end

    def address
      object_id
    end

    def state
      @state
    end

    def stats
      {
        name: name,
        address: address,
        state: state,
        message_count: @mailbox.length
      }
    end

    def start
      # pass the @block to use high performance yield instead of @block.yield
      @thread = run(&@block)
      @thread.name = name
    end

    private def start_hooks
      @state = RUNNING
    end

    private def stop_hooks
      @state = STOPPED
    end

    private def run(&block)
      Thread.new do
        start_hooks

        loop do
          message = get_message

          log "Processing Message #{message}"
          break if stop_message?(message)

          yield(message) if block_given?
        end

        stop_hooks
      end
    end

    def log(text)
      puts "#{name} #{address} -> #{text}" if $debug_mode
    end

    def await
      @thread.join
    end

    def stopped?
      @state == STOPPED
    end

    private def get_message
      @state = WAITING
      message = @mailbox.dequeue
      @state = RUNNING
      message
    end

    private def stop_message?(message)
      message == ControlMessage::STOP
    end

    def cleanup
      @mailbox = []
      @thread = nil
      @state = STOPPED
    end
  end
end