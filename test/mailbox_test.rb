require 'stage/mailbox'

MailBox = Stage::MailBox

def check(name, ok)
  raise "FAIL: #{name}" unless ok
  puts "ok - #{name}"
end

mailbox = MailBox.new
check("is empty by default", mailbox.empty? && mailbox.length == 0)

mailbox = MailBox.new
check("returns ok on enqueue", mailbox.enqueue("hello") == Stage::ControlMessage::OK)

mailbox = MailBox.new
3.times { |i| mailbox.enqueue(i) }
check("tracks the number of messages",
      !mailbox.empty? && mailbox.length == 3 && mailbox.count == 3 && mailbox.size == 3)

mailbox = MailBox.new
mailbox.enqueue(:first)
mailbox.enqueue(:second)
first = mailbox.dequeue
second = mailbox.dequeue
check("dequeues messages in FIFO order",
      first == :first && second == :second && mailbox.empty?)

mailbox = MailBox.new
stop = Stage::ControlMessage::STOP
mailbox.enqueue(stop)
check("accepts control messages", mailbox.dequeue.equal?(stop))

max_length = 3
mailbox = MailBox.new(max_size: max_length)
max_length.times { |i| mailbox.enqueue(i) }
result = mailbox.enqueue(:overflow) # warns on stderr
check("rejects messages once full",
      result == Stage::ControlMessage::REJECTED && mailbox.length == max_length)

mailbox = MailBox.new
reader = Thread.new { mailbox.dequeue }
sleep 0.05
waiting = reader.alive?
mailbox.enqueue(:late)
check("blocks dequeue until a message arrives", waiting && reader.value == :late)
