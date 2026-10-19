require_relative 'control_message'
# A MailBox is a queue associated with an Actor
# a message sent to Actor is sent to its MailBox.
# actor processes each messages one by one at a time.
# a Message in mailbox contains sender address and receiver address.

module Actor
  class MailBox
    MAX_SIZE = 100

    attr_reader :queue

    def initialize
      @queue = Queue.new
    end

    def enqueue(item)
      unless queue.size < MAX_SIZE
        warn('Message rejected queue full')
        return ControlMessage::REJECTED
      end

      @queue.push(item)
      ControlMessage::OK
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

    alias_method :count, :length
    alias_method :size, :length
  end
end