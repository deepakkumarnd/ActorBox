require_relative 'control_message'
# A MailBox is a queue associated with an Actor
# a message sent to Actor is sent to its MailBox.
# actor processes each messages one by one at a time.
# a Message in mailbox contains sender address and receiver address.

module ActorBox
  class MailBox
    attr_reader :queue, :max_size

    # @rbs (?max_size: Integer?) -> void
    def initialize(max_size: nil)
      @max_size = max_size
      # queue is unbounded by default
      @queue = @max_size ? SizedQueue.new(@max_size) : Queue.new
    end

    #: (untyped) -> ActorBox::ControlMessage::CType
    def enqueue(item)
      # unbounded queue
      if unbounded?
        queue.push(item)
        ControlMessage::OK
      # Reject if queue is full with zero timeout
      elsif (queue.size < max_size) && queue.push(item, timeout: 0)
        ControlMessage::OK 
      else
        warn('Message rejected queue full')
        ControlMessage::REJECTED
      end
    end

    def dequeue
      @queue.pop
    end

    def empty?
      @queue.empty?
    end

    def length
      @queue.size
    end

    def unbounded?
      @max_size.nil?
    end

    alias_method :count, :length
    alias_method :size, :length
  end
end