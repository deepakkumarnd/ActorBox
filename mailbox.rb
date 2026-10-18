# A message is a subclass of Message, an actor can send or receive 
# messages.
 
class ControlMessage
  attr_reader :from, :to

  def initialize(to, from)
    @from = from
    @to = to
  end

  class << self
    def rejected
      :rejected
    end

    def ok
      :ok
    end

    def stop
      StopActor.new
    end
  end
end

# Control messages
class StopActor < ControlMessage
  def initialize
    super(nil, nil)
  end
end

# A MailBox is a queue associated with an Actor
# a message sent to Actor is sent to its MailBox.
# actor processes each messages one by one at a time.
# a Message in mailbox contains sender address and receiver address.

class MailBox
  MAX_SIZE = 100

  attr_reader :queue

  def initialize
    @queue = Queue.new
  end

  def enqueue(item)
    unless queue.size < MAX_SIZE
      warn('Message rejected queue full')
      return ControlMessage.rejected
    end

    @queue.push(item)
    ControlMessage.ok
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